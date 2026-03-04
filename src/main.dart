import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  // 日本語フォントを読み込む
  final fontData = await File('fonts/ShipporiMincho-Regular.ttf').readAsBytes();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  const fontSize = 12.0;
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
            return pw.SizedBox(height: fontSize);
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
              style: pw.TextStyle(font: ttf, fontSize: fontSize),
            ));
          }

          final rubyRegex = RegExp(r'｜(.+?)《(.+?)》');
          int lastIndex = 0;

          for (final rubyMatch in rubyRegex.allMatches(textContent)) {
            if (rubyMatch.start > lastIndex) {
              spans.add(pw.TextSpan(
                text: textContent.substring(lastIndex, rubyMatch.start),
                style: pw.TextStyle(font: ttf, fontSize: fontSize),
              ));
            }

            final kanji = rubyMatch.group(1)!;
            final ruby = rubyMatch.group(2)!;

            spans.add(
              pw.WidgetSpan(
                // baselineを負の値に設定して、ウィジェット全体を下げる。
                // 0だとウィジェットの下端がベースラインに来てしまい、漢字が浮いて見えるため。
                baseline: -fontSize * 0.29,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      ruby,
                      style: pw.TextStyle(font: ttf, fontSize: fontSize * 0.5), // ルビは半分のサイズ
                    ),
                    pw.Text(
                      kanji,
                      style: pw.TextStyle(font: ttf, fontSize: fontSize),
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
              style: pw.TextStyle(font: ttf, fontSize: fontSize),
            ));
          }

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 2.0),
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