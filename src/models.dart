import 'package:pdf/widgets.dart' as pw;

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