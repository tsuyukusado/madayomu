import 'dart:io';

import '../domain/models.dart';

// ファイルリストを本文と奥付に分けて結合する
Future<NovelContent> mergeTexts(List<File> files) async {
  final buffer = StringBuffer();
  String? okuduke;

  for (final file in files) {
    if (file.path.endsWith('99_okuduke.md')) {
      okuduke = await file.readAsString();
      continue;
    }
    buffer.write(await file.readAsString());
    buffer.writeln();
  }

  return NovelContent(buffer.toString(), okuduke);
}
