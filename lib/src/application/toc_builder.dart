import '../domain/models.dart';

// 本文から目次データを作る純粋なロジック（外部ライブラリに依存しない）
List<TocEntry> buildToc(String content) {
  final toc = <TocEntry>[];
  final lines = content.split(RegExp(r'\r?\n'));
  bool inCodeBlock = false;

  for (final line in lines) {
    if (line.trim().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      continue;
    }
    if (inCodeBlock) continue;

    final headerMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(line);
    if (headerMatch != null) {
      final hashes = headerMatch.group(1)!;
      final text = headerMatch.group(2)!.trim();
      if (text != 'index') {
        toc.add(TocEntry(hashes.length, text));
      }
    }
  }

  return toc;
}
