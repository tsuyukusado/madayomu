import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'text_token.dart';

// テキストをTokenのリストに分解する（PDFに依存しない純粋な関数）
List<TextToken> parseTokens(String text) {
  final tokens = <TextToken>[];
  final regex = RegExp(r'(`[^`]+`)|(｜.+?《.+?》)|(\*\*.+?\*\*)');
  int lastIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      tokens.add(PlainToken(text.substring(lastIndex, match.start)));
    }

    final matchedText = match.group(0)!;

    if (match.group(1) != null) {
      // インラインコード (`...`)
      tokens.add(InlineCodeToken(matchedText.substring(1, matchedText.length - 1)));
    } else if (match.group(2) != null) {
      // ルビ・圏点 (｜...《...》)
      final rubyMatch = RegExp(r'｜(.+?)《(.+?)》').firstMatch(matchedText);
      if (rubyMatch != null) {
        final base = rubyMatch.group(1)!;
        final ruby = rubyMatch.group(2)!;
        if (ruby == '圏') {
          tokens.add(KantenToken(base));
        } else {
          tokens.add(RubyToken(base: base, ruby: ruby));
        }
      }
    } else if (match.group(3) != null) {
      // 太字 (**...**)
      tokens.add(BoldToken(matchedText.substring(2, matchedText.length - 2)));
    }

    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    tokens.add(PlainToken(text.substring(lastIndex)));
  }

  return tokens;
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
