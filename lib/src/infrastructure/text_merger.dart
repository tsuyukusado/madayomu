import 'dart:io';

import '../domain/models.dart';

// ファイルリストを結合し、# okuduke セクションを奥付として抽出する
Future<NovelContent> mergeTexts(List<File> files) async {
  final buffer = StringBuffer();

  for (final file in files) {
    buffer.write(await file.readAsString());
    buffer.writeln();
  }

  return extractOkuduke(buffer.toString());
}
