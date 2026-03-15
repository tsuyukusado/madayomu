import '../domain/models.dart';
import 'interfaces/i_pdf_renderer.dart';
import 'numbering.dart';
import 'toc_builder.dart';

// 変換の指揮（番号振り→目次生成→レンダリング）
// IPdfRendererを受け取るので、将来CLIでもFlutterでも差し替えられる
Future<List<int>> convertToPdf(NovelContent novel, IPdfRenderer renderer) async {
  final content = applyNumbering(novel.content); // 章番号を振る
  final toc = buildToc(content);                 // 目次データを作る
  return renderer.render(content, novel.okuduke, toc); // レンダリングを依頼
}
