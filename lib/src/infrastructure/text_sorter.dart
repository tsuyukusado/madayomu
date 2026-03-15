import 'dart:io';

// ファイルリストをファイル名順に並び替える
List<File> sortTexts(List<File> files) {
  final sorted = List<File>.from(files);
  sorted.sort((a, b) => a.path.compareTo(b.path));
  return sorted;
}
