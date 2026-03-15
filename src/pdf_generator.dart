import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'markdown_parser.dart';
import 'models.dart';

class PdfGenerator {
  PdfGenerator(FontSet fonts)
      : ttf = fonts.ttf,
        gothicTtf = fonts.gothicTtf,
        codeTtf = fonts.codeTtf;

  final pw.Font ttf;
  final pw.Font gothicTtf;
  final pw.Font codeTtf;

  static const fontSize = 9.0;
  static const lineSpacing = 4.0;

  Future<List<int>> generate({
    required String content,
    required String? okudukeContent,
    required List<TocEntry> toc,
    required Map<String, int> headerPageMap,
    required bool isDryRun,
  }) async {
    final pdf = pw.Document();

    // 画像の事前読み込み
    final imageCache = <String, pw.MemoryImage>{};
    final imageRegex = RegExp(r'^｜(.*\.png)$', multiLine: true);
    for (final match in imageRegex.allMatches(content)) {
      final imageName = match.group(1)!;
      if (!imageCache.containsKey(imageName)) {
        final file = File('novel/$imageName');
        if (await file.exists()) {
          imageCache[imageName] = pw.MemoryImage(await file.readAsBytes());
        }
      }
    }

    final parser = MarkdownParser(
      ttf: ttf,
      codeTtf: codeTtf,
      gothicTtf: gothicTtf,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      imageCache: imageCache,
      toc: toc,
      headerPageMap: headerPageMap,
      isDryRun: isDryRun,
    );

    final sections = content.split('===page===');

    for (final section in sections) {
      if (section.trim().isEmpty) continue;
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a5,
          // 余白を調整（上下15mm、左右10mm）して、ページ番号を端に寄せる
          margin: pw.EdgeInsets.symmetric(vertical: 15.0 * PdfPageFormat.mm, horizontal: 10.0 * PdfPageFormat.mm),
          theme: pw.ThemeData.withFont(base: ttf),
          footer: (context) {
            final pageNum = context.pageNumber;
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 5.0),
              child: pw.Text(
                '$pageNum',
                style: pw.TextStyle(font: ttf, fontSize: fontSize),
              ),
            );
          },
          build: (context) => parser.parse(section),
        ),
      );
    }

    // 奥付ページの追加
    if (okudukeContent != null) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: pw.EdgeInsets.symmetric(vertical: 15.0 * PdfPageFormat.mm, horizontal: 10.0 * PdfPageFormat.mm),
          theme: pw.ThemeData.withFont(base: ttf),
          build: (context) {
            final widgets = parser.parse(okudukeContent, useFullWidth: false);
            return pw.Container(
              alignment: pw.Alignment.bottomRight,
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: widgets,
              ),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }
}