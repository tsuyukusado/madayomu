import 'package:pdf/widgets.dart' as pw;

// フォントのまとまりのクラス
class FontSet {
  final pw.Font ttf;
  final pw.Font gothicTtf;
  final pw.Font codeTtf;
  FontSet(this.ttf, this.gothicTtf, this.codeTtf);
}

// 本文と奥付をまとめたクラス
class NovelContent {
  final String content;
  final String? okuduke;
  NovelContent(this.content, this.okuduke);
}

// 禁則処理のために文字とメタデータを保持するクラス
class BuiltItem {
  final pw.Widget widget;
  final bool isKinsoku;
  BuiltItem(this.widget, {this.isKinsoku = false});
}

class TocEntry {
  final int level;
  final String text;
  TocEntry(this.level, this.text);
}