//src/main.dart
// まずここが動く

// 他ファイルをインポート
import 'text_loader.dart';
import 'text_sorter.dart';
import 'text_merger.dart';
import 'pdf_converter.dart';
import 'pdf_exporter.dart';

void // 何も戻り値を返さないという意味。
main() // 引数なし
async // 複数人同時にやる時、待機が発生した場合次の人が動くようにする
{ //この中に関数が入る
  final files = await loadTexts();          // 1. 読み込む
  final sorted = sortTexts(files);          // 2. 並び替える
  final novel = await mergeTexts(sorted);   // 3. 結合する
  final bytes = await convertToPdf(novel);  // 4. 変換する
  await exportPdf(bytes, 'test.pdf');       // 5. 出力する
}
