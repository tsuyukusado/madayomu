import 'dart:io';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  // 日本語フォントを読み込む
  final fontData = await File('fonts/ShipporiMincho-Regular.ttf').readAsBytes();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  final inputFile = File('novel/00_tsukuritai.md');
  final content = await inputFile.readAsString();
  final sections = content.split('===page===');

  for (final section in sections) {
    if (section.trim().isEmpty) continue;
    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) => section.trim().split(RegExp(r'\r?\n')).map((line) {
          return pw.Text(line);
        }).toList(),
      ),
    );
  }

  final file = File('test.pdf');
  await file.writeAsBytes(await pdf.save());
  
  print('PDFができたぜ！');
}