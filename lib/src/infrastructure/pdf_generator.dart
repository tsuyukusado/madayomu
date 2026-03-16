import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'font.dart';
import 'markdown_parser.dart';
import 'widgets.dart';
import '../domain/models.dart';

class PdfGenerator {
  PdfGenerator(
    FontSet fonts, {
    this.leftMarginMm = 12.5,  // 電子書籍: 12.5 / 印刷用内側: 20
    this.rightMarginMm = 12.5, // 電子書籍: 12.5 / 印刷用外側: 5
    this.isPrint = false,
  })  : ttf = fonts.ttf,
        gothicTtf = fonts.gothicTtf,
        codeTtf = fonts.codeTtf;

  final pw.Font ttf;
  final pw.Font gothicTtf;
  final pw.Font codeTtf;
  final double leftMarginMm;
  final double rightMarginMm;
  final bool isPrint;

  static const fontSize = 9.0;
  static const lineSpacing = 4.0;

  Future<List<int>> generate({
    required String content,
    required String? okudukeContent,
    required List<TocEntry> toc,
    required Map<String, int> headerPageMap,
    required bool isDryRun,
    Map<String, pw.MemoryImage> imageCache = const {}, // 画像は外から渡す（プラットフォームごとに読み方が違うため）
  }) async {
    final pdf = pw.Document();

    final sections = content.split('===page===')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    for (int sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      final sectionKey = '__section_$sectionIndex\__';

      // 印刷用: セクション開始ページに応じて内側・外側マージンを切り替える
      double left = leftMarginMm;
      double right = rightMarginMm;
      if (isPrint && !isDryRun) {
        final startPage = headerPageMap[sectionKey] ?? 1;
        // 奇数ページ開始 → 右綴じ: 左=内側(20)、右=外側(5)
        // 偶数ページ開始 → 右綴じ: 左=外側(5)、右=内側(20)
        if (startPage.isOdd) {
          left = leftMarginMm;
          right = rightMarginMm;
        } else {
          left = rightMarginMm;
          right = leftMarginMm;
        }
      }

      final parser = MarkdownParser(
        ttf: ttf,
        codeTtf: codeTtf,
        gothicTtf: gothicTtf,
        fontSize: fontSize,
        lineSpacing: lineSpacing,
        leftMarginMm: left,
        rightMarginMm: right,
        imageCache: imageCache,
        toc: toc,
        headerPageMap: headerPageMap,
        isDryRun: isDryRun,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a5,
          margin: pw.EdgeInsets.fromLTRB(left * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm, right * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm),
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
          build: (context) {
            final widgets = <pw.Widget>[];
            // ドライラン時: セクション開始ページを記録するためのPageRecorderを先頭に挿入
            if (isDryRun) {
              widgets.add(PageRecorder(
                child: pw.SizedBox(height: 0),
                onPageRecorded: (page) {
                  headerPageMap[sectionKey] = page;
                },
              ));
            }
            widgets.addAll(parser.parse(section));
            return widgets;
          },
        ),
      );
    }

    // 奥付ページの追加
    if (okudukeContent != null) {
      final okudukeParser = MarkdownParser(
        ttf: ttf,
        codeTtf: codeTtf,
        gothicTtf: gothicTtf,
        fontSize: fontSize,
        lineSpacing: lineSpacing,
        leftMarginMm: leftMarginMm,
        rightMarginMm: rightMarginMm,
        imageCache: imageCache,
        toc: toc,
        headerPageMap: headerPageMap,
        isDryRun: isDryRun,
      );
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: pw.EdgeInsets.fromLTRB(leftMarginMm * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm, rightMarginMm * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm),
          theme: pw.ThemeData.withFont(base: ttf),
          build: (context) {
            final widgets = okudukeParser.parse(okudukeContent, useFullWidth: false);
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