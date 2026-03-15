import 'dart:io';

// novelフォルダから.mdファイルのリストを読み込む
Future<List<File>> loadTexts() async {
  final directory = Directory('novel');
  return directory.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
}
