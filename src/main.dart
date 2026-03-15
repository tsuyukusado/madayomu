//src/main.dart
// まずここが動く

// 他ファイルをインポート
import 'infrastructure/text_loader.dart';
import 'infrastructure/text_sorter.dart';
import 'infrastructure/text_merger.dart';
import 'infrastructure/pdf_renderer.dart';
import 'infrastructure/pdf_exporter.dart';
import 'application/converter.dart';

void // 何も戻り値を返さないという意味。
main() // 引数なし
async // 複数人同時にやる時、待機が発生した場合次の人が動くようにする
{ //この中に関数が入る
  final files = await loadTexts();                        // 1. 読み込む
  final sorted = sortTexts(files);                        // 2. 並び替える
  final novel = await mergeTexts(sorted);                 // 3. 結合する
  final renderer = CliPdfRenderer();                      // 4a. レンダラーを選ぶ（CLI用）
  final bytes = await convertToPdf(novel, renderer);      // 4b. 変換する
  await exportPdf(bytes, 'test.pdf');                     // 5. 出力する
}
