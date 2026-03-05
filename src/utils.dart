import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// 太字、インラインコード、ルビをまとめてパースする関数
List<pw.InlineSpan> parseRichText(
  String text, {
  required pw.Font ttf,
  required pw.Font codeTtf,
  required pw.Font gothicTtf,
  required double fontSize,
}) {
  final spans = <pw.InlineSpan>[];
  // 優先順位: インラインコード > ルビ > 太字
  final regex = RegExp(r'(`[^`]+`)|(｜.+?《.+?》)|(\*\*.+?\*\*)');
  int lastIndex = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(pw.TextSpan(
        text: text.substring(lastIndex, match.start),
        style: pw.TextStyle(font: ttf, fontSize: fontSize),
      ));
    }

    final matchedText = match.group(0)!;

    if (match.group(1) != null) {
      // Group 1: インラインコード (`...`)
      spans.add(pw.TextSpan(
        text: matchedText.substring(1, matchedText.length - 1),
        style: pw.TextStyle(font: codeTtf, fontSize: fontSize, color: PdfColors.white),
      ));
    } else if (match.group(2) != null) {
      // Group 2: ルビ (｜漢字《ルビ》)
      final rubyContentMatch = RegExp(r'｜(.+?)《(.+?)》').firstMatch(matchedText);
      if (rubyContentMatch != null) {
        final kanji = rubyContentMatch.group(1)!;
        final ruby = rubyContentMatch.group(2)!;

        if (ruby == '圏') {
          // 傍点（圏点）の処理
          for (final char in kanji.runes) {
            final charStr = String.fromCharCode(char);
            spans.add(
              pw.WidgetSpan(
                baseline: -fontSize * 0.25,
                child: pw.Stack(
                  overflow: pw.Overflow.visible,
                  children: [
                    pw.Text(
                      charStr,
                      style: pw.TextStyle(font: ttf, fontSize: fontSize),
                    ),
                    pw.Positioned(
                      top: -fontSize * 0.45,
                      left: 0,
                      right: 0,
                      child: pw.Center(
                        child: pw.Text(
                          '﹅',
                          style: pw.TextStyle(font: ttf, fontSize: fontSize * 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          // 通常のルビ処理
          spans.add(
            pw.WidgetSpan(
              baseline: -fontSize * 0.25,
              child: pw.Stack(
                overflow: pw.Overflow.visible,
                children: [
                  pw.Text(
                    kanji,
                    style: pw.TextStyle(font: ttf, fontSize: fontSize),
                  ),
                  pw.Positioned(
                    top: -fontSize * 0.45,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: pw.Text(
                        ruby,
                        style: pw.TextStyle(font: ttf, fontSize: fontSize * 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } else if (match.group(3) != null) {
      // Group 3: 太字 (**...**)
      spans.add(pw.TextSpan(
        text: matchedText.substring(2, matchedText.length - 2),
        style: pw.TextStyle(font: gothicTtf, fontSize: fontSize),
      ));
    }
    lastIndex = match.end;
  }
  if (lastIndex < text.length) {
    spans.add(pw.TextSpan(
      text: text.substring(lastIndex),
      style: pw.TextStyle(font: ttf, fontSize: fontSize),
    ));
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
    // Markdown Highlight
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