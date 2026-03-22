// 本文と奥付をまとめたクラス
class NovelContent {
  final String content;
  final String? okuduke;
  NovelContent(this.content, this.okuduke);
}

// コードブロック内の ===page=== を無視してページ分割する
List<String> splitByPageBreak(String content) {
  final sections = <String>[];
  final buffer = StringBuffer();
  bool inCodeBlock = false;

  for (final line in content.split(RegExp(r'\r?\n'))) {
    if (line.trim().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      buffer.writeln(line);
    } else if (!inCodeBlock && line.trim() == '===page===') {
      sections.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.writeln(line);
    }
  }
  if (buffer.isNotEmpty) sections.add(buffer.toString());

  return sections.where((s) => s.trim().isNotEmpty).toList();
}

// マージ済みテキストから # okuduke セクションを奥付として抽出する
NovelContent extractOkuduke(String content) {
  final sections = splitByPageBreak(content);
  String? okuduke;
  final mainSections = <String>[];
  final okudukeRegex = RegExp(r'^\s*#\s*okuduke\s*$', caseSensitive: false, multiLine: true);

  for (final section in sections) {
    if (okudukeRegex.hasMatch(section)) {
      okuduke = section.replaceFirst(RegExp(r'^\s*#\s*okuduke[^\n]*\n?', caseSensitive: false), '');
    } else {
      mainSections.add(section);
    }
  }

  return NovelContent(mainSections.join('\n===page===\n'), okuduke);
}

// 禁則処理のために文字とメタデータを保持するクラス
class TocEntry {
  final int level;
  final String text;
  TocEntry(this.level, this.text);
}
