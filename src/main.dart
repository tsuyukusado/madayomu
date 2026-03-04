import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  // 日本語フォントを読み込む
  final fontData = await File('fonts/ShipporiMincho-Regular.ttf').readAsBytes();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  const fontSize = 12.0;
  const lineSpacing = 8.0; // 行間を広げる設定（フォントサイズの約0.6倍）
  final inputFile = File('novel/00_tsukuritai.md');
  final content = await inputFile.readAsString();
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
                style: pw.TextStyle(font: ttf, fontSize: fontSize * 2), // フォントサイズを倍に
              ),
            );
          }

          // 行頭のあらゆる空白文字（全角・半角・タブ）を検出
          final match = RegExp(r'^([\s\u3000]+)').firstMatch(line);
          String indentString = '';
          String textContent = line;

          if (match != null) {
            final spaces = match.group(1)!;
            double indentWidth = 0.0;
            // 空白の種類に応じて幅を計算
            for (final codePoint in spaces.runes) {
              if (codePoint == 0x3000) { // 全角スペース
                indentWidth += fontSize;
              } else { // 半角スペースなど
                indentWidth += fontSize * 0.5; // 半角スペースは半分の幅として計算
              }
            }
            textContent = line.substring(match.end);
            // アイの提案：Em Space (U+2003) を使う
            final spaceCount = (indentWidth / fontSize).round() * 5;
            indentString = '\u2003' * spaceCount;
          }

          // ルビの解析と適用
          final List<pw.InlineSpan> spans = [];
          
          // インデントがある場合は先頭に追加
          if (indentString.isNotEmpty) {
            spans.add(pw.TextSpan(
              text: indentString,
              style: pw.TextStyle(font: ttf, fontSize: fontSize, lineSpacing: lineSpacing),
            ));
          }

          final rubyRegex = RegExp(r'｜(.+?)《(.+?)》');
          int lastIndex = 0;

          for (final rubyMatch in rubyRegex.allMatches(textContent)) {
            if (rubyMatch.start > lastIndex) {
              spans.add(pw.TextSpan(
                text: textContent.substring(lastIndex, rubyMatch.start),
                style: pw.TextStyle(font: ttf, fontSize: fontSize, lineSpacing: lineSpacing),
              ));
            }

            final kanji = rubyMatch.group(1)!;
            final ruby = rubyMatch.group(2)!;

            spans.add(
              pw.WidgetSpan(
                // 漢字の位置を合わせるためにbaselineを調整
                baseline: -fontSize * 0.25,
                child: pw.Stack(
                  overflow: pw.Overflow.visible, // 領域外（ルビ部分）が切り取られないように表示許可を与える
                  children: [
                    // 基準となる漢字（Stackのサイズはこの要素で決まる）
                    pw.Text(
                      kanji,
                      style: pw.TextStyle(font: ttf, fontSize: fontSize),
                    ),
                    // ルビを絶対配置で上に置く
                    // Stackを使うことで、WidgetSpanの高さ計算にルビが含まれなくなり、行間が広がるのを防ぐ
                    pw.Positioned(
                      top: -fontSize * 0.45, // 漢字の上に配置（値は微調整してください）
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
            lastIndex = rubyMatch.end;
          }

          if (lastIndex < textContent.length) {
            spans.add(pw.TextSpan(
              text: textContent.substring(lastIndex),
              style: pw.TextStyle(font: ttf, fontSize: fontSize, lineSpacing: lineSpacing),
            ));
          }

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: lineSpacing),
            child: pw.RichText(
              text: pw.TextSpan(children: spans),
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