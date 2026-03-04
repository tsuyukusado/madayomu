import 'dart:io';
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
          final match = RegExp(r'^(\u3000+)').firstMatch(line);
          if (match != null) {
            final spaceCount = match.group(1)!.length;
            final text = line.substring(match.group(1)!.length);
            return pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.WidgetSpan(child: pw.SizedBox(width: fontSize * spaceCount)),
                  pw.TextSpan(text: text),
                ],
              ),
            );
          }
          return pw.Text(line);
        }).toList(),
      ),
    );
  }

  final file = File('test.pdf');
  await file.writeAsBytes(await pdf.save());
  
  print('PDFができたぜ！');
}