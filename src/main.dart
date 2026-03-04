import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  // 日本語フォントを読み込む
  final fontData = await File('fonts/ShipporiMincho-Regular.ttf').readAsBytes();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  // ゴシック体（太字）フォントを読み込む ※ファイル名は実際の環境に合わせて変更してください
  final gothicFontData = await File('fonts/NotoSansJP-Bold.ttf').readAsBytes();
  final gothicTtf = pw.Font.ttf(gothicFontData.buffer.asByteData());

  // コード用（等幅）フォントを読み込む ※ファイル名は実際の環境に合わせて変更してください
  // 日本語対応の等幅フォント（例: BIZ UDGothic）を使用
  final codeFontData = await File('fonts/BIZUDGothic-Bold.ttf').readAsBytes();
  final codeTtf = pw.Font.ttf(codeFontData.buffer.asByteData());

  const fontSize = 12.0;
  const lineSpacing = 4.0; // 行間を広げる設定（フォントサイズの約0.6倍）

  final directory = Directory('novel');
  final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
  files.sort((a, b) => a.path.compareTo(b.path));

  // 太字、インラインコード、ルビをまとめてパースするローカル関数
  List<pw.InlineSpan> parseRichText(String text) {
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

  final buffer = StringBuffer();
  for (final file in files) {
    buffer.write(await file.readAsString());
    buffer.writeln();
  }
  final content = buffer.toString();

  final sections = content.split('===page===');

  for (final section in sections) {
    if (section.trim().isEmpty) continue;
    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) => section.split(RegExp(r'\r?\n')).map((line) {
          // 空行の場合は、1行分のスペースを空ける
          if (line.isEmpty) {
            return pw.SizedBox(height: fontSize + lineSpacing);
          }

          // 見出し行の検出 (# で始まる行)
          final headerMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(line);
          if (headerMatch != null) {
            final text = headerMatch.group(2)!;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10.0, top: 5.0), // 見出しの上下に少し余白を入れる
              child: pw.Text(
                text,
                style: pw.TextStyle(font: gothicTtf, fontSize: fontSize * 2), // フォントサイズを倍に
              ),
            );
          }

          // 行頭のあらゆる空白文字（全角・半角・タブ）を検出
          final match = RegExp(r'^([\s\u3000]+)').firstMatch(line);
          double indentWidth = 0.0;
          String textContent = line;

          if (match != null) {
            final spaces = match.group(1)!;
            // 空白の種類に応じて幅を計算
            for (final codePoint in spaces.runes) {
              if (codePoint == 0x3000) { // 全角スペース
                indentWidth += fontSize;
              } else { // 半角スペースなど
                indentWidth += fontSize * 0.5; // 半角スペースは半分の幅として計算
              }
            }
            textContent = line.substring(match.end);
          }

          // ルビの解析と適用
          final List<pw.InlineSpan> spans = [];
          
          // インデントがある場合は先頭に追加
          if (indentWidth > 0) {
            spans.add(pw.WidgetSpan(
              child: pw.SizedBox(width: indentWidth, height: fontSize),
            ));
          }

          spans.addAll(parseRichText(textContent));

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: lineSpacing),
            width: double.infinity,
            child: pw.Wrap(
              runSpacing: lineSpacing,
              children: spans.expand<pw.Widget>((span) {
                if (span is pw.TextSpan) {
                  // TextSpanを文字単位のTextウィジェットに分解し、Wrapが正しく改行できるようにする
                  final text = span.text ?? '';
                  return text.runes.map((rune) {
                    if (rune == 0x3000) {
                      // 全角スペースの場合はフォントサイズ分の空きを作る
                      return pw.SizedBox(width: fontSize, height: fontSize);
                    } else if (rune == 0x0020 || rune == 0x0009) {
                      // 半角スペース・タブの場合は半分の幅
                      return pw.SizedBox(width: fontSize * 0.5, height: fontSize);
                    }

                    final charWidget = pw.Text(
                      String.fromCharCode(rune),
                      style: span.style,
                    );

                    // インラインコード（コード用フォント）の場合は背景を黒にする
                    if (span.style?.font == codeTtf) {
                      return pw.Container(
                        // フォントのベースラインが異なるため、上部にマージンを追加して位置を下げる
                        margin: const pw.EdgeInsets.only(top: 2.0),
                        // 背景を文字の外側に広げる（上下2px、左右1px）
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                        color: PdfColors.black,
                        child: charWidget,
                      );
                    }
                    return charWidget;
                  });
                } else if (span is pw.WidgetSpan) {
                  // WidgetSpanの場合はそのchild（Stack）をそのままリストに入れる
                  return [span.child];
                }
                return <pw.Widget>[];
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  final file = File('test.pdf');
  await file.writeAsBytes(await pdf.save());
  print('PDFができたぜ！');
}