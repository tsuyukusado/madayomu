import '../application/interfaces/i_pdf_renderer.dart';
import '../domain/models.dart';
import 'font.dart';
import 'pdf_generator.dart';

// IPdfRendererの実装（CLIやデスクトップ向け）
// フォントをファイルから読み込んでPDFを生成する
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

    // 1回目（ページ番号取得用）
    await generator.generate(
      content: content,
      okudukeContent: okuduke,
      toc: toc,
      headerPageMap: headerPageMap,
      isDryRun: true,
    );

    // 2回目（本番出力用）
    return generator.generate(
      content: content,
      okudukeContent: okuduke,
      toc: toc,
      headerPageMap: headerPageMap,
      isDryRun: false,
    );
  }
}
