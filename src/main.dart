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
        build: (context) => section.split(RegExp(r'\r?\n'))
            .where((line) => line.isNotEmpty) // 空行を除去して、無駄な空白処理を防ぐ
            .map((line) {
          // 行頭のあらゆる空白文字（全角・半角・タブ）を検出
          final match = RegExp(r'^([\s\u3000]+)').firstMatch(line);
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
            final text = line.substring(match.end);
            // アイの提案：Em Space (U+2003) を使う
            // これは「1文字分の幅（1em）」を持つ空白文字として定義されているため、
            // フォントに依存せず全角幅を確保しやすく、文字として連結できるので改行も起きない。
            // ユーザーの要望により、空白を広げる（元の計算値の2倍にする）
            final spaceCount = (indentWidth / fontSize).round() * 5;
            final indentString = '\u2003' * spaceCount;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 2.0), // 行間を少し空ける
              child: pw.Text(
                indentString + text,
                style: pw.TextStyle(font: ttf, fontSize: fontSize),
              ),
            );
          }
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 2.0),
            child: pw.Text(line),
          );
        }).toList(),
      ),
    );
  }

  final file = File('test.pdf');
  await file.writeAsBytes(await pdf.save());
  print('PDFができたぜ！');
}