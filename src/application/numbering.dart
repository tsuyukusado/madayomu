// 見出しに章番号を振る純粋なロジック（外部ライブラリに依存しない）
String applyNumbering(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final numbered = <String>[];
  int chapterCount = 0;
  int sectionCount = 0;
  bool inCodeBlock = false;

  for (final line in lines) {
    if (line.trim().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      numbered.add(line);
      continue;
    }
    if (inCodeBlock) {
      numbered.add(line);
      continue;
    }

    final headerMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(line);
    if (headerMatch != null && headerMatch.group(2)!.trim() != 'index') {
      final hashes = headerMatch.group(1)!;
      if (hashes.length == 1) {
        sectionCount = 0;
        numbered.add('# $chapterCount. ${headerMatch.group(2)!.trim()}');
        chapterCount++;
      } else if (hashes.length == 2) {
        sectionCount++;
        numbered.add('## $chapterCount-$sectionCount. ${headerMatch.group(2)!.trim()}');
      } else {
        numbered.add(line);
      }
    } else {
      numbered.add(line);
    }
  }

  return numbered.join('\n');
}
