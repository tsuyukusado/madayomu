import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// 禁則処理のために文字とメタデータを保持するクラス
class BuiltItem {
  final pw.Widget widget;
  final bool isKinsoku;
  BuiltItem(this.widget, {this.isKinsoku = false});
}

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
        build: (context) {
          final lines = section.split(RegExp(r'\r?\n'));
          final widgets = <pw.Widget>[];
          bool inCodeBlock = false;
          final codeBuffer = StringBuffer();

          for (final line in lines) {
            // コードブロックの判定 (```)
            if (line.trim().startsWith('```')) {
              if (inCodeBlock) {
                // コードブロック終了
                inCodeBlock = false;
                widgets.add(pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: lineSpacing),
                  padding: const pw.EdgeInsets.all(4.0),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.black,
                    borderRadius: pw.BorderRadius.circular(4.0),
                  ),
                  child: pw.Text(
                    codeBuffer.toString().trimRight(),
                    style: pw.TextStyle(font: codeTtf, fontSize: fontSize, color: PdfColors.white, lineSpacing: lineSpacing),
                  ),
                ));
                codeBuffer.clear();
              } else {
                // コードブロック開始
                inCodeBlock = true;
              }
              continue;
            }

            if (inCodeBlock) {
              codeBuffer.writeln(line);
              continue;
            }

            // 空行の場合は、1行分のスペースを空ける
            if (line.isEmpty) {
              widgets.add(pw.SizedBox(height: fontSize + lineSpacing));
              continue;
            }

            // 水平線の検出 (---)
            if (RegExp(r'^---+$').hasMatch(line.trim())) {
              widgets.add(pw.Divider());
              continue;
            }

            // 見出し行の検出 (# で始まる行)
            final headerMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(line);
            if (headerMatch != null) {
              final text = headerMatch.group(2)!;
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10.0, top: 5.0), // 見出しの上下に少し余白を入れる
                child: pw.Text(
                  text,
                  style: pw.TextStyle(font: gothicTtf, fontSize: fontSize * 2), // フォントサイズを倍に
                ),
              ));
              continue;
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

            // 禁則文字セット（行頭に来てはいけない文字）
            const kinsokuChars = {'、', '。', 'っ', 'ゃ', 'ゅ', 'ょ', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'ゎ', 'ヵ', 'ヶ', 'ー', '…', '！', '？', '!', '?', ')', '）', ']', '］', '}', '｝', '」', '』', ',', '.'};

            final builtItems = <BuiltItem>[];

            // 1. すべてのSpanを文字単位のBuiltItemリストに展開
            for (final span in spans) {
              if (span is pw.TextSpan) {
                final text = span.text ?? '';
                final runes = text.runes.toList();
                for (int i = 0; i < runes.length; i++) {
                  final rune = runes[i];
                  final charStr = String.fromCharCode(rune);

                  if (rune == 0x3000) {
                    builtItems.add(BuiltItem(pw.SizedBox(width: fontSize, height: fontSize)));
                    continue;
                  } else if (rune == 0x0020 || rune == 0x0009) {
                    builtItems.add(BuiltItem(pw.SizedBox(width: fontSize * 0.5, height: fontSize)));
                    continue;
                  }

                  pw.Widget charWidget = pw.Text(charStr, style: span.style);

                  // インラインコードの装飾
                  if (span.style?.font == codeTtf) {
                    const radius = pw.Radius.circular(4.0);
                    final isFirst = i == 0;
                    final isLast = i == runes.length - 1;

                    charWidget = pw.Container(
                      margin: const pw.EdgeInsets.only(top: 2.0),
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.black,
                        borderRadius: pw.BorderRadius.horizontal(
                          left: isFirst ? radius : pw.Radius.zero,
                          right: isLast ? radius : pw.Radius.zero,
                        ),
                      ),
                      child: charWidget,
                    );
                  }

                  builtItems.add(BuiltItem(charWidget, isKinsoku: kinsokuChars.contains(charStr)));
                }
              } else if (span is pw.WidgetSpan) {
                builtItems.add(BuiltItem(span.child));
              }
            }

            // 2. 禁則文字を直前の要素と結合して最終的なWidgetリストを作成
            final finalWidgets = <pw.Widget>[];
            for (final item in builtItems) {
              if (item.isKinsoku && finalWidgets.isNotEmpty) {
                // 禁則文字なら、直前のWidgetを取り出して結合する
                final prev = finalWidgets.removeLast();
                finalWidgets.add(pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [prev, item.widget],
                ));
              } else {
                finalWidgets.add(item.widget);
              }
            }

            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(bottom: lineSpacing),
              width: double.infinity,
              child: pw.Wrap(
                runSpacing: lineSpacing,
                children: finalWidgets,
              ),
            ));
          }
          return widgets;
        },
      ),
    );
  }

  final file = File('test.pdf');
  await file.writeAsBytes(await pdf.save());
  print('PDFができたぜ！');
}