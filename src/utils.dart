import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'text_token.dart';

// 一文字ベースでルビが3文字以上の場合、隣のプレーンテキストから文字を吸収して再配分する
List<TextToken> _processRubyOverflow(List<TextToken> tokens) {
  final result = <TextToken>[];
  int i = 0;

  while (i < tokens.length) {
    final token = tokens[i];

    if (token is RubyToken) {
      final baseRunes = token.base.runes.toList();
      final rubyRunes = token.ruby.runes.toList();

      if (baseRunes.length == 1 && rubyRunes.length > 2) {
        final totalBaseNeeded = (rubyRunes.length / 2.0).ceil();
        final extraNeeded = totalBaseNeeded - 1;

        bool handled = false;
        if (extraNeeded > 0 && i + 1 < tokens.length && tokens[i + 1] is PlainToken) {
          final nextPlain = tokens[i + 1] as PlainToken;
          final nextRunes = nextPlain.text.runes.toList();

          if (extraNeeded <= nextRunes.length) {
            final absorbedRunes = nextRunes.take(extraNeeded).toList();
            final remainingRunes = nextRunes.skip(extraNeeded).toList();

            final allBaseRunes = [baseRunes.first, ...absorbedRunes];
            final rubyPerBase = (rubyRunes.length / allBaseRunes.length).ceil();

            int rubyIndex = 0;
            for (final baseRune in allBaseRunes) {
              final slice = rubyRunes.skip(rubyIndex).take(rubyPerBase).toList();
              rubyIndex += slice.length;
              while (slice.length < rubyPerBase) {
                slice.add(0x3000); // 全角スペースで埋める
              }
              result.add(RubyToken(
                base: String.fromCharCode(baseRune),
                ruby: String.fromCharCodes(slice),
              ));
            }

            if (remainingRunes.isNotEmpty) {
              result.add(PlainToken(String.fromCharCodes(remainingRunes)));
            }

            i += 2;
            handled = true;
          }
        }

        if (!handled) {
          print('[警告] ルビが正常に表示されません: ｜${token.base}《${token.ruby}》');
          result.add(token);
          i++;
        }
      } else {
        result.add(token);
        i++;
      }
    } else {
      result.add(token);
      i++;
    }
  }

  return result;
}

// ベースが複数文字のルビを一文字ずつのRubyTokenに分割する
List<RubyToken> _splitRuby(String base, String ruby) {
  final baseRunes = base.runes.toList();
  if (baseRunes.length == 1) return [RubyToken(base: base, ruby: ruby)];

  final rubyRunes = ruby.runes.toList();
  final rubyPerBase = (rubyRunes.length / baseRunes.length).ceil();

  final result = <RubyToken>[];
  int rubyIndex = 0;

  for (final baseRune in baseRunes) {
    final slice = rubyRunes.skip(rubyIndex).take(rubyPerBase).toList();
    rubyIndex += slice.length;

    while (slice.length < rubyPerBase) {
      slice.add(0x3000);
    }

    result.add(RubyToken(base: String.fromCharCode(baseRune), ruby: String.fromCharCodes(slice)));
  }

  return result;
}

// テキストをTokenのリストに分解する（PDFに依存しない純粋な関数）
List<TextToken> parseTokens(String text) {
  final rawTokens = <TextToken>[];
  final regex = RegExp(r'(`[^`]+`)|(｜.+?《.+?》)|(\*\*.+?\*\*)');
  int lastIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      rawTokens.add(PlainToken(text.substring(lastIndex, match.start)));
    }

    final matchedText = match.group(0)!;

    if (match.group(1) != null) {
      // インラインコード (`...`)
      rawTokens.add(InlineCodeToken(matchedText.substring(1, matchedText.length - 1)));
    } else if (match.group(2) != null) {
      // ルビ・圏点 (｜...《...》)
      final rubyMatch = RegExp(r'｜(.+?)《(.+?)》').firstMatch(matchedText);
      if (rubyMatch != null) {
        final base = rubyMatch.group(1)!;
        final ruby = rubyMatch.group(2)!;
        if (ruby == '圏') {
          rawTokens.add(KantenToken(base));
        } else {
          rawTokens.add(RubyToken(base: base, ruby: ruby));
        }
      }
    } else if (match.group(3) != null) {
      // 太字 (**...**)
      rawTokens.add(BoldToken(matchedText.substring(2, matchedText.length - 2)));
    }

    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    rawTokens.add(PlainToken(text.substring(lastIndex)));
  }

  // Step 1: 一文字ベースでルビが長すぎる場合、隣から吸収して再配分
  final overflowProcessed = _processRubyOverflow(rawTokens);

  // Step 2: 複数文字ベースを一文字ずつに分割
  final result = <TextToken>[];
  for (final token in overflowProcessed) {
    if (token is RubyToken) {
      result.addAll(_splitRuby(token.base, token.ruby));
    } else {
      result.add(token);
    }
  }

  return result;
}

// TokenのリストをPDFのInlineSpanリストに変換する
List<pw.InlineSpan> parseRichText(
  String text, {
  required pw.Font ttf,
  required pw.Font codeTtf,
  required pw.Font gothicTtf,
  required double fontSize,
}) {
  final tokens = parseTokens(text);
  final spans = <pw.InlineSpan>[];

  for (final token in tokens) {
    if (token is PlainToken) {
      spans.add(pw.TextSpan(
        text: token.text,
        style: pw.TextStyle(font: ttf, fontSize: fontSize),
      ));
    } else if (token is BoldToken) {
      spans.add(pw.TextSpan(
        text: token.text,
        style: pw.TextStyle(font: gothicTtf, fontSize: fontSize),
      ));
    } else if (token is InlineCodeToken) {
      spans.add(pw.TextSpan(
        text: token.text,
        style: pw.TextStyle(font: codeTtf, fontSize: fontSize, color: PdfColors.white),
      ));
    } else if (token is RubyToken) {
      // overflow処理後、各ベースに対するルビは最大2文字なのでStackの幅は常にベース文字幅と同等
      spans.add(pw.WidgetSpan(
        baseline: -fontSize * 0.25,
        child: pw.Stack(
          overflow: pw.Overflow.visible,
          children: [
            pw.Text(token.base, style: pw.TextStyle(font: ttf, fontSize: fontSize)),
            pw.Positioned(
              top: -fontSize * 0.45,
              left: 0,
              right: 0,
              child: pw.Center(
                child: pw.Text(token.ruby, style: pw.TextStyle(font: ttf, fontSize: fontSize * 0.5)),
              ),
            ),
          ],
        ),
      ));
    } else if (token is KantenToken) {
      for (final char in token.text.runes) {
        final charStr = String.fromCharCode(char);
        spans.add(pw.WidgetSpan(
          baseline: -fontSize * 0.25,
          child: pw.Stack(
            overflow: pw.Overflow.visible,
            children: [
              pw.Text(charStr, style: pw.TextStyle(font: ttf, fontSize: fontSize)),
              pw.Positioned(
                top: -fontSize * 0.45,
                left: 0,
                right: 0,
                child: pw.Center(
                  child: pw.Text('﹅', style: pw.TextStyle(font: ttf, fontSize: fontSize * 0.5)),
                ),
              ),
            ],
          ),
        ));
      }
    }
  }

  return spans;
}

// シンタックスハイライト用の関数
pw.TextSpan highlightCode(String text, String language, pw.Font font, pw.Font fallbackFont, double fontSize) {
  final spans = <pw.InlineSpan>[];
  final defaultStyle = pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.white, fontFallback: [fallbackFont]);

  if (language == 'dart') {
    final tokenRegex = RegExp(
      r'(//.*)|' // Group 1: Comment
      r'(".*?")|' // Group 2: Double quoted string
      r"('.*?')|" // Group 3: Single quoted string
      r'(\b(?:void|var|final|const|class|import|package|return|if|else|for|while|do|switch|case|break|continue|true|false|null|this|super|new|extends|with|implements|async|await|try|catch|finally|throw|rethrow|assert|int|double|String|bool|List|Map|Set|dynamic|print|late|required|extension|mixin|enum|typedef|Function|is|as|in)\b)|' // Group 4: Keywords
      r'(\b\d+(\.\d+)?\b)', // Group 5: Numbers
    );

    int lastIndex = 0;
    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(pw.TextSpan(text: text.substring(lastIndex, match.start), style: defaultStyle));
      }

      final matchedText = match.group(0)!;
      PdfColor color = PdfColors.white;

      if (match.group(1) != null) {
        color = PdfColors.grey500;
      } else if (match.group(2) != null || match.group(3) != null) {
        color = PdfColors.green300;
      } else if (match.group(4) != null) {
        color = PdfColors.purple300;
      } else if (match.group(5) != null) {
        color = PdfColors.orange300;
      }

      spans.add(pw.TextSpan(text: matchedText, style: defaultStyle.copyWith(color: color)));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(pw.TextSpan(text: text.substring(lastIndex), style: defaultStyle));
    }
  } else if (language == 'md' || language == 'markdown') {
    if (text.trimLeft().startsWith('#')) {
      spans.add(pw.TextSpan(text: text, style: defaultStyle.copyWith(color: PdfColors.blue300)));
    } else {
      final mdRegex = RegExp(r'(`[^`]+`)');
      int lastIndex = 0;
      for (final match in mdRegex.allMatches(text)) {
        if (match.start > lastIndex) {
          spans.add(pw.TextSpan(text: text.substring(lastIndex, match.start), style: defaultStyle));
        }
        spans.add(pw.TextSpan(text: match.group(1), style: defaultStyle.copyWith(color: PdfColors.yellow200)));
        lastIndex = match.end;
      }
      if (lastIndex < text.length) {
        spans.add(pw.TextSpan(text: text.substring(lastIndex), style: defaultStyle));
      }
    }
  } else {
    spans.add(pw.TextSpan(text: text, style: defaultStyle));
  }

  return pw.TextSpan(children: spans);
}
