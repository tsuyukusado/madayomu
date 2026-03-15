import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

import '../application/interfaces/i_pdf_renderer.dart';
import '../domain/models.dart';
import 'font.dart';
import 'pdf_generator.dart';

// IPdfRendererの実装（CLIやデスクトップ向け）
// フォントと画像をファイルシステムから読み込んでPDFを生成する
class CliPdfRenderer implements IPdfRenderer {
  @override
  Future<List<int>> render(
    String content,
    String? okuduke,
    List<TocEntry> toc,
  ) async {
    final fonts = await loadFonts();
    final generator = PdfGenerator(fonts);
    final headerPageMap = <String, int>{};

    // 画像をファイルから読み込む（CLI専用）
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

    // 1回目（ページ番号取得用）
    await generator.generate(
      content: content,
      okudukeContent: okuduke,
      toc: toc,
      headerPageMap: headerPageMap,
      isDryRun: true,
      imageCache: imageCache,
    );

    // 2回目（本番出力用）
    return generator.generate(
      content: content,
      okudukeContent: okuduke,
      toc: toc,
      headerPageMap: headerPageMap,
      isDryRun: false,
      imageCache: imageCache,
    );
  }
}
