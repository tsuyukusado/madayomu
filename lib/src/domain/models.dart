// 本文と奥付をまとめたクラス
class NovelContent {
  final String content;
  final String? okuduke;
  NovelContent(this.content, this.okuduke);
}

// 禁則処理のために文字とメタデータを保持するクラス
class TocEntry {
  final int level;
  final String text;
  TocEntry(this.level, this.text);
}
