import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import '../src/application/interfaces/i_pdf_renderer.dart';
import '../src/domain/models.dart';
import '../src/infrastructure/font.dart';
import '../src/infrastructure/pdf_generator.dart';

// IPdfRendererの実装（Flutter/Web向け）
// フォントをアセットから読み込んでPDFを生成する（dart:ioを使わない）
class FlutterPdfRenderer implements IPdfRenderer {
  FlutterPdfRenderer({
    this.leftMarginMm = 12.5,  // 電子書籍: 12.5 / 印刷用内側: 20
    this.rightMarginMm = 12.5, // 電子書籍: 12.5 / 印刷用外側: 5
    this.isPrint = false,
  });

  final double leftMarginMm;
  final double rightMarginMm;
  final bool isPrint;

  @override
  Future<List<int>> render(
    String content,
    String? okuduke,
    List<TocEntry> toc, {
    Map<String, Uint8List> imageData = const {},
  }) async {
    // Uint8List → pw.MemoryImage に変換
    final imageCache = {
      for (final e in imageData.entries) e.key: pw.MemoryImage(e.value),
    };

    final fonts = await _loadFontsFromAssets();
    final generator = PdfGenerator(fonts, leftMarginMm: leftMarginMm, rightMarginMm: rightMarginMm, isPrint: isPrint);
    final headerPageMap = <String, int>{};

    final widgetPageMap = isPrint ? <int, int>{} : null;

    // 1回目（ページ番号取得用）
    await generator.generate(
      content: content,
      okudukeContent: okuduke,
      toc: toc,
      headerPageMap: headerPageMap,
      isDryRun: true,
      imageCache: imageCache,
      widgetPageMap: widgetPageMap,
    );

    // 2回目（本番出力用）
    return generator.generate(
      content: content,
      okudukeContent: okuduke,
      toc: toc,
      headerPageMap: headerPageMap,
      isDryRun: false,
      imageCache: imageCache,
      widgetPageMap: widgetPageMap,
    );
  }

  // アセットからフォントを読み込む（CLIのloadFonts()のFlutter版）
  Future<FontSet> _loadFontsFromAssets() async {
    final ttfData      = await rootBundle.load('fonts/ShipporiMincho-Regular.ttf');
    final gothicData   = await rootBundle.load('fonts/NotoSansJP-Bold.ttf');
    final codeData     = await rootBundle.load('fonts/BIZUDGothic-Bold.ttf');

    return FontSet(
      pw.Font.ttf(ttfData),
      pw.Font.ttf(gothicData),
      pw.Font.ttf(codeData),
    );
  }
}
