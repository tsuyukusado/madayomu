import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  // 日本語フォントを読み込む
  final fontData = await File('fonts/ShipporiMincho-Regular.ttf').readAsBytes();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  const fontSize = 12.0;
  const lineSpacing = 4.0; // 行間を広げる設定（フォントサイズの約0.6倍）

  final directory = Directory('novel');
  final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
  files.sort((a, b) => a.path.compareTo(b.path));

  final buffer = StringBuffer();
  for (final file in files) {
    buffer.write(await file.readAsString());
    buffer.writeln();
  }
  final content = buffer.toString();

  final sections = content.split('===page===');

  for (final section in sections) {
    if (section.trim().isEmpty) continue;
    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) => section.split(RegExp(r'\r?\n')).map((line) {
          // 空行の場合は、1行分のスペースを空ける
          if (line.isEmpty) {
            return pw.SizedBox(height: fontSize + lineSpacing);
          }

          // 見出し行の検出 (# で始まる行)
          final headerMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(line);
          if (headerMatch != null) {
            final text = headerMatch.group(2)!;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10.0, top: 5.0), // 見出しの上下に少し余白を入れる
              child: pw.Text(
                text,
                style: pw.TextStyle(font: ttf, fontSize: fontSize * 2), // フォントサイズを倍に
              ),
            );
          }

          // 行頭のあらゆる空白文字（全角・半角・タブ）を検出
          final match = RegExp(r'^([\s\u3000]+)').firstMatch(line);
          double indentWidth = 0.0;
          String textContent = line;

          if (match != null) {
            final spaces = match.group(1)!;
            // 空白の種類に応じて幅を計算
            for (final codePoint in spaces.runes) {
              if (codePoint == 0x3000) { // 全角スペース
                indentWidth += fontSize;
              } else { // 半角スペースなど
                indentWidth += fontSize * 0.5; // 半角スペースは半分の幅として計算
              }
            }
            textContent = line.substring(match.end);
          }

          // ルビの解析と適用
          final List<pw.InlineSpan> spans = [];
          
          // インデントがある場合は先頭に追加
          if (indentWidth > 0) {
            spans.add(pw.WidgetSpan(
              child: pw.SizedBox(width: indentWidth, height: fontSize),
            ));
          }

          final rubyRegex = RegExp(r'｜(.+?)《(.+?)》');
          int lastIndex = 0;

          for (final rubyMatch in rubyRegex.allMatches(textContent)) {
            if (rubyMatch.start > lastIndex) {
              spans.add(pw.TextSpan(
                text: textContent.substring(lastIndex, rubyMatch.start),
                style: pw.TextStyle(font: ttf, fontSize: fontSize),
              ));
            }

            final kanji = rubyMatch.group(1)!;
            final ruby = rubyMatch.group(2)!;

            if (ruby == '圏') {
              // 傍点（圏点）の処理：1文字ずつ分解して「﹅」を打つ
              for (final char in kanji.runes) {
                final charStr = String.fromCharCode(char);
                spans.add(
                  pw.WidgetSpan(
                    baseline: -fontSize * 0.25,
                    child: pw.Stack(
                      overflow: pw.Overflow.visible,
                      children: [
                        pw.Text(
                          charStr,
                          style: pw.TextStyle(font: ttf, fontSize: fontSize),
                        ),
                        pw.Positioned(
                          top: -fontSize * 0.45,
                          left: 0,
                          right: 0,
                          child: pw.Center(
                            child: pw.Text(
                              '﹅',
                              style: pw.TextStyle(font: ttf, fontSize: fontSize * 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            } else {
              // 通常のルビ処理
              spans.add(
                pw.WidgetSpan(
                  // 漢字の位置を合わせるためにbaselineを調整
                  baseline: -fontSize * 0.25,
                  child: pw.Stack(
                    overflow: pw.Overflow.visible, // 領域外（ルビ部分）が切り取られないように表示許可を与える
                    children: [
                      // 基準となる漢字（Stackのサイズはこの要素で決まる）
                      pw.Text(
                        kanji,
                        style: pw.TextStyle(font: ttf, fontSize: fontSize),
                      ),
                      // ルビを絶対配置で上に置く
                      // Stackを使うことで、WidgetSpanの高さ計算にルビが含まれなくなり、行間が広がるのを防ぐ
                      pw.Positioned(
                        top: -fontSize * 0.45, // 漢字の上に配置（値は微調整してください）
                        left: 0,
                        right: 0,
                        child: pw.Center(
                          child: pw.Text(
                            ruby,
                            style: pw.TextStyle(font: ttf, fontSize: fontSize * 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            lastIndex = rubyMatch.end;
          }

          if (lastIndex < textContent.length) {
            spans.add(pw.TextSpan(
              text: textContent.substring(lastIndex),
              style: pw.TextStyle(font: ttf, fontSize: fontSize),
            ));
          }

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: lineSpacing),
            width: double.infinity,
            child: pw.Wrap(
              runSpacing: lineSpacing,
              children: spans.expand<pw.Widget>((span) {
                if (span is pw.TextSpan) {
                  // TextSpanを文字単位のTextウィジェットに分解し、Wrapが正しく改行できるようにする
                  final text = span.text ?? '';
                  return text.runes.map((rune) => pw.Text(
                        String.fromCharCode(rune),
                        style: span.style,
                      ));
                } else if (span is pw.WidgetSpan) {
                  // WidgetSpanの場合はそのchild（Stack）をそのままリストに入れる
                  return [span.child];
                }
                return <pw.Widget>[];
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  final file = File('test.pdf');
  await file.writeAsBytes(await pdf.save());
  print('PDFができたぜ！');
}