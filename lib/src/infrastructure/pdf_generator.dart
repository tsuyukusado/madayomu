import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'font.dart';
import 'markdown_parser.dart';
import 'widgets.dart';
import '../domain/models.dart';

class PdfGenerator {
  PdfGenerator(
    FontSet fonts, {
    this.leftMarginMm = 12.5,  // 電子書籍: 12.5 / 印刷用内側: 18
    this.rightMarginMm = 12.5, // 電子書籍: 12.5 / 印刷用外側: 7
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
    Map<String, pw.MemoryImage> imageCache = const {},
    // 印刷モードのドライランで収集: ウィジェットのグローバルインデックス→物理ページ番号
    Map<int, int>? widgetPageMap,
  }) async {
    if (isPrint && !isDryRun) {
      return _generatePrintRealRun(
        content, okudukeContent, toc, headerPageMap, widgetPageMap!, imageCache,
      );
    }
    return _generateStandard(
      content, okudukeContent, toc, headerPageMap, isDryRun, imageCache, widgetPageMap,
    );
  }

  // 電子版 or ドライラン: MultiPage で自動ページ分割
  Future<List<int>> _generateStandard(
    String content,
    String? okudukeContent,
    List<TocEntry> toc,
    Map<String, int> headerPageMap,
    bool isDryRun,
    Map<String, pw.MemoryImage> imageCache,
    Map<int, int>? widgetPageMap,
  ) async {
    final pdf = pw.Document();
    final sections = content.split('===page===')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    int globalWidgetIndex = 0;

    for (int si = 0; si < sections.length; si++) {
      final sectionKey = '__section_${si}__';

      final parser = MarkdownParser(
        ttf: ttf, codeTtf: codeTtf, gothicTtf: gothicTtf,
        fontSize: fontSize, lineSpacing: lineSpacing,
        leftMarginMm: leftMarginMm, rightMarginMm: rightMarginMm,
        imageCache: imageCache, toc: toc,
        headerPageMap: headerPageMap, isDryRun: isDryRun,
      );

      final sectionWidgets = parser.parse(sections[si]);
      final baseIndex = globalWidgetIndex;
      globalWidgetIndex += sectionWidgets.length;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.fromLTRB(
          leftMarginMm * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm,
          rightMarginMm * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: ttf),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 5.0),
          child: pw.Text('${context.pageNumber}',
              style: pw.TextStyle(font: ttf, fontSize: fontSize)),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          // セクション開始ページをヘッダーページマップに記録
          if (isDryRun) {
            widgets.add(PageRecorder(
              child: pw.SizedBox(height: 0),
              onPageRecorded: (page) => headerPageMap[sectionKey] = page,
            ));
          }

          // 印刷モードのドライランでは各ウィジェットのページ番号も記録
          for (int i = 0; i < sectionWidgets.length; i++) {
            if (isDryRun && isPrint && widgetPageMap != null) {
              final idx = baseIndex + i;
              widgets.add(PageRecorder(
                child: sectionWidgets[i],
                onPageRecorded: (page) => widgetPageMap[idx] = page,
              ));
            } else {
              widgets.add(sectionWidgets[i]);
            }
          }
          return widgets;
        },
      ));
    }

    if (okudukeContent != null) {
      _addOkudukePage(pdf, okudukeContent, toc, headerPageMap, isDryRun, imageCache,
          leftMarginMm, rightMarginMm);
    }

    return await pdf.save();
  }

  // 印刷本番: 物理ページごとに個別 MultiPage を作り、奇数偶数でマージンを切り替える
  //
  // 重要な前提: leftMarginMm + rightMarginMm は奇数用・偶数用どちらでも同じ値。
  // bodyMargin も含めると実効コンテンツ幅は常に A5 - 2*(left+right) で一定なので、
  // ドライランと本番でテキスト折り返しが一致し、ページ分割も同じになる。
  Future<List<int>> _generatePrintRealRun(
    String content,
    String? okudukeContent,
    List<TocEntry> toc,
    Map<String, int> headerPageMap,
    Map<int, int> widgetPageMap,
    Map<String, pw.MemoryImage> imageCache,
  ) async {
    final pdf = pw.Document();
    final sections = content.split('===page===')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    // 奇数ページ用・偶数ページ用の2セットのウィジェットを事前生成
    // コンテンツ幅は同一なのでページ分割はドライランと完全に一致する
    final allWidgetsOdd  = <pw.Widget>[];  // 奇数: left=inner(18), right=outer(7)
    final allWidgetsEven = <pw.Widget>[];  // 偶数: left=outer(7),  right=inner(18)

    for (final section in sections) {
      final parserOdd = _makeParser(
        leftMarginMm, rightMarginMm, toc, headerPageMap, imageCache,
      );
      final parserEven = _makeParser(
        rightMarginMm, leftMarginMm, toc, headerPageMap, imageCache,
      );
      allWidgetsOdd.addAll(parserOdd.parse(section));
      allWidgetsEven.addAll(parserEven.parse(section));
    }

    // ウィジェットインデックスを物理ページ番号でグループ化
    final pageToWidgetIndices = <int, List<int>>{};
    for (final e in widgetPageMap.entries) {
      pageToWidgetIndices.putIfAbsent(e.value, () => []).add(e.key);
    }

    final sortedPageNums = pageToWidgetIndices.keys.toList()..sort();

    for (final pageNum in sortedPageNums) {
      final isOdd = pageNum.isOdd;
      final left  = isOdd ? leftMarginMm  : rightMarginMm;
      final right = isOdd ? rightMarginMm : leftMarginMm;

      final indices = pageToWidgetIndices[pageNum]!..sort();
      final pageWidgets = indices.map((i) =>
          isOdd ? allWidgetsOdd[i] : allWidgetsEven[i]).toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.fromLTRB(
          left * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm,
          right * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: ttf),
        footer: (context) => pw.Container(
          alignment: isOdd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(top: 5.0),
          child: pw.Text('$pageNum',
              style: pw.TextStyle(font: ttf, fontSize: fontSize)),
        ),
        build: (context) => pageWidgets,
      ));
    }

    if (okudukeContent != null) {
      final okudukePageNum = (sortedPageNums.isEmpty ? 0 : sortedPageNums.last) + 1;
      final isOdd = okudukePageNum.isOdd;
      final left  = isOdd ? leftMarginMm  : rightMarginMm;
      final right = isOdd ? rightMarginMm : leftMarginMm;
      _addOkudukePage(pdf, okudukeContent, toc, headerPageMap, false, imageCache,
          left, right);
    }

    return await pdf.save();
  }

  MarkdownParser _makeParser(
    double left, double right,
    List<TocEntry> toc, Map<String, int> headerPageMap,
    Map<String, pw.MemoryImage> imageCache,
  ) => MarkdownParser(
    ttf: ttf, codeTtf: codeTtf, gothicTtf: gothicTtf,
    fontSize: fontSize, lineSpacing: lineSpacing,
    leftMarginMm: left, rightMarginMm: right,
    imageCache: imageCache, toc: toc,
    headerPageMap: headerPageMap, isDryRun: false,
  );

  void _addOkudukePage(
    pw.Document pdf,
    String okudukeContent,
    List<TocEntry> toc,
    Map<String, int> headerPageMap,
    bool isDryRun,
    Map<String, pw.MemoryImage> imageCache,
    double left, double right,
  ) {
    final parser = _makeParser(left, right, toc, headerPageMap, imageCache);
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.fromLTRB(
        left * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm,
        right * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm,
      ),
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
    ));
  }
}
