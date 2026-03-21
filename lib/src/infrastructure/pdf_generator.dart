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

  // フッターウィジェットの高さ（ポイント単位）: fontSize + top margin
  static const double _footerHeightPt = fontSize + 5.0;

  Future<List<int>> generate({
    required String content,
    required String? okudukeContent,
    required List<TocEntry> toc,
    required Map<String, int> headerPageMap,
    required bool isDryRun,
    Map<String, pw.MemoryImage> imageCache = const {},
    Map<int, int>? widgetPageMap,
  }) async {
    final pdf = pw.Document();

    final sections = content.split('===page===')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    // 印刷用・本番ラン: ページ単位で余白・ページ番号位置を切り替える
    if (isPrint && !isDryRun && widgetPageMap != null) {
      _generatePrintPages(pdf, sections, toc, headerPageMap, imageCache, widgetPageMap,
        showMadayomuOnLastPage: okudukeContent == null);
    } else {
      // 電子用 or ドライラン: MultiPage でそのままレンダリング
      int globalWidgetIndex = 0;

      for (int sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
        final section = sections[sectionIndex];
        final sectionKey = '__section_$sectionIndex\__';

        final parser = MarkdownParser(
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
          pw.MultiPage(
            pageFormat: PdfPageFormat.a5,
            margin: pw.EdgeInsets.fromLTRB(leftMarginMm * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm, rightMarginMm * PdfPageFormat.mm, 15.0 * PdfPageFormat.mm),
            theme: pw.ThemeData.withFont(base: ttf),
            footer: (context) {
              final pageNum = context.pageNumber;
              final showMadayomu = okudukeContent == null &&
                  sectionIndex == sections.length - 1 &&
                  context.pageNumber == context.pagesCount;
              return pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    margin: const pw.EdgeInsets.only(top: 5.0),
                    child: pw.Text(
                      '$pageNum',
                      style: pw.TextStyle(font: ttf, fontSize: fontSize),
                    ),
                  ),
                  if (showMadayomu)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('This book was made with madayomu.', style: pw.TextStyle(font: ttf, fontSize: fontSize)),
                        pw.Text('https://tsuyukusado.com/madayomu', style: pw.TextStyle(font: ttf, fontSize: fontSize)),
                      ],
                    ),
                ],
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
              final sectionWidgets = parser.parse(section);
              final baseIndex = globalWidgetIndex;
              globalWidgetIndex += sectionWidgets.length;
              for (int i = 0; i < sectionWidgets.length; i++) {
                if (isDryRun && isPrint && widgetPageMap != null) {
                  final idx = baseIndex + i;
                  widgets.add(PageRecorder(
                    isAtomic: true,
                    child: sectionWidgets[i],
                    onPageRecorded: (page) => widgetPageMap[idx] = page,
                  ));
                } else {
                  widgets.add(NoSpanWidget(child: sectionWidgets[i]));
                }
              }
              return widgets;
            },
          ),
        );
      }
    }

    // 奥付ページの追加
    if (okudukeContent != null) {
      // 奥付は最後のページ番号の奇偶に合わせる（印刷用でも奥付は固定レイアウト）
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
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.bottomRight,
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: widgets,
                    ),
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('This book was made with madayomu.', style: pw.TextStyle(font: ttf, fontSize: fontSize)),
                    pw.Text('https://tsuyukusado.com/madayomu', style: pw.TextStyle(font: ttf, fontSize: fontSize)),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  /// 印刷用本番ラン: widgetPageMap を使いページ単位で pw.Page を生成する。
  /// 奇数ページ: 左マージン広(leftMarginMm)・右マージン狭(rightMarginMm)・ページ番号右下
  /// 偶数ページ: 左マージン狭(rightMarginMm)・右マージン広(leftMarginMm)・ページ番号左下
  void _generatePrintPages(
    pw.Document pdf,
    List<String> sections,
    List<TocEntry> toc,
    Map<String, int> headerPageMap,
    Map<String, pw.MemoryImage> imageCache,
    Map<int, int> widgetPageMap, {
    bool showMadayomuOnLastPage = false,
  }) {
    // 奇数・偶数それぞれのマージンでウィジェットをパースする
    // （左右合計は同じなのでテキスト幅・改行位置は変わらない）
    final oddWidgets = <int, pw.Widget>{}; // globalIdx → 奇数ページ用ウィジェット
    final evenWidgets = <int, pw.Widget>{}; // globalIdx → 偶数ページ用ウィジェット
    int gIdx = 0;

    for (final section in sections) {
      final oddParser = MarkdownParser(
        ttf: ttf, codeTtf: codeTtf, gothicTtf: gothicTtf,
        fontSize: fontSize, lineSpacing: lineSpacing,
        leftMarginMm: leftMarginMm, rightMarginMm: rightMarginMm,
        imageCache: imageCache, toc: toc, headerPageMap: headerPageMap, isDryRun: false,
      );
      final evenParser = MarkdownParser(
        ttf: ttf, codeTtf: codeTtf, gothicTtf: gothicTtf,
        fontSize: fontSize, lineSpacing: lineSpacing,
        leftMarginMm: rightMarginMm, rightMarginMm: leftMarginMm, // 左右反転
        imageCache: imageCache, toc: toc, headerPageMap: headerPageMap, isDryRun: false,
      );

      final oddSection = oddParser.parse(section);
      final evenSection = evenParser.parse(section);

      for (int i = 0; i < oddSection.length; i++) {
        oddWidgets[gIdx] = oddSection[i];
        evenWidgets[gIdx] = evenSection[i];
        gIdx++;
      }
    }

    // ページ番号でグループ化
    final pageGroups = <int, List<pw.Widget>>{};
    for (int idx = 0; idx < gIdx; idx++) {
      final pageNum = widgetPageMap[idx] ?? 1;
      final isOdd = pageNum.isOdd;
      final widget = isOdd ? oddWidgets[idx]! : evenWidgets[idx]!;
      pageGroups.putIfAbsent(pageNum, () => []).add(widget);
    }

    // ページ順に pw.Page を生成
    final pageNumbers = pageGroups.keys.toList()..sort();
    for (final pageNum in pageNumbers) {
      final isOdd = pageNum.isOdd;
      final left = isOdd ? leftMarginMm : rightMarginMm;
      final right = isOdd ? rightMarginMm : leftMarginMm;
      final footerAlignment = isOdd ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
      final widgets = pageGroups[pageNum]!;
      final isLastPage = pageNum == pageNumbers.last;

      // フッター分だけ下マージンを縮小してコンテンツ高さをドライランと合わせる
      final bottomMarginPt = 15.0 * PdfPageFormat.mm - _footerHeightPt;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: pw.EdgeInsets.fromLTRB(
            left * PdfPageFormat.mm,
            15.0 * PdfPageFormat.mm,
            right * PdfPageFormat.mm,
            bottomMarginPt,
          ),
          theme: pw.ThemeData.withFont(base: ttf),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: widgets,
                  ),
                ),
                pw.Container(
                  alignment: footerAlignment,
                  margin: const pw.EdgeInsets.only(top: 5.0),
                  child: pw.Text(
                    '$pageNum',
                    style: pw.TextStyle(font: ttf, fontSize: fontSize),
                  ),
                ),
                if (showMadayomuOnLastPage && isLastPage)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('This book was made with madayomu.', style: pw.TextStyle(font: ttf, fontSize: fontSize)),
                      pw.Text('https://tsuyukusado.com/madayomu', style: pw.TextStyle(font: ttf, fontSize: fontSize)),
                    ],
                  ),
              ],
            );
          },
        ),
      );
    }
  }
}