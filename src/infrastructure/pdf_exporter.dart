import 'dart:io';

// PDFのバイト列をファイルに書き出す
Future<void> exportPdf(List<int> bytes, String path) async {
  final file = File(path);
  await file.writeAsBytes(bytes);
  print('PDFができたぜ！');
}
