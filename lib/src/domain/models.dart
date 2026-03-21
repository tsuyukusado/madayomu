// 本文と奥付をまとめたクラス
class NovelContent {
  final String content;
  final String? okuduke;
  NovelContent(this.content, this.okuduke);
}

// マージ済みテキストから # okuduke セクションを奥付として抽出する
NovelContent extractOkuduke(String content) {
  final sections = content.split('===page===');
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

  return NovelContent(mainSections.join('===page==='), okuduke);
}

// 禁則処理のために文字とメタデータを保持するクラス
class TocEntry {
  final int level;
  final String text;
  TocEntry(this.level, this.text);
}
