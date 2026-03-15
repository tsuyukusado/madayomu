//　フォントの読み込みを切り出した関数

import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'models.dart';

// 3種類のフォントをまとめて読み込んでFontSetで返す
Future// まだ完成していない値の入れ物。asyncの時に使う。
<FontSet>// 型を指定する
loadFonts() async // この処理が動いている間は二人目が動いても問題ない
{
  final pathMap = { // パスと名前をセットにしたMap。Map：名前で管理するリスト
    'ttf':       'fonts/ShipporiMincho-Regular.ttf', // 明朝体
    'gothicTtf': 'fonts/NotoSansJP-Bold.ttf',        // 太字ゴシック体
    'codeTtf':   'fonts/BIZUDGothic-Bold.ttf',       // コード用
  };

  final fontMap = <String, pw.Font>{}; // 名前とpw.Fontのセットを入れる空のMap
  for (final entry in pathMap.entries) { // pathMapを一つずつ処理する
    final data = await File(entry.value).readAsBytes(); // Mapのvalue（ファイルパス）で読み込む
    fontMap[entry.key] = pw.Font.ttf(data.buffer.asByteData()); // バイト列をpw.Fontに変換してMapに入れる
  }

  return FontSet(
    fontMap['ttf']!,       // !はnullじゃないことを保証する印
    fontMap['gothicTtf']!,
    fontMap['codeTtf']!,
  );
}
