import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models.dart';
import 'utils.dart';
import 'widgets.dart';

// 禁則処理のために文字とメタデータを保持するクラス
class BuiltItem {
  final pw.Widget widget;
  final bool isKinsoku;
  BuiltItem(this.widget, {this.isKinsoku = false});
}

class MarkdownParser {
  MarkdownParser({
    required this.ttf,
    required this.codeTtf,
    required this.gothicTtf,
    required this.fontSize,
    required this.lineSpacing,
    this.leftMarginMm = 12.5,  // 電子書籍: 12.5 / 印刷用内側: 20
    this.rightMarginMm = 12.5, // 電子書籍: 12.5 / 印刷用外側: 5
    required this.imageCache,
    required this.toc,
    required this.headerPageMap,
    required this.isDryRun,
  });

  final pw.Font ttf;
  final pw.Font codeTtf;
  final pw.Font gothicTtf;
  final double fontSize;
  final double lineSpacing;
  final double leftMarginMm;
  final double rightMarginMm;
  final Map<String, pw.MemoryImage> imageCache;
  final List<TocEntry> toc;
  final Map<String, int> headerPageMap;
  final bool isDryRun;

  List<pw.Widget> parse(String text, {bool useFullWidth = true}) {
    final lines = text.split(RegExp(r'\r?\n'));
    final widgets = <pw.Widget>[];
    bool inCodeBlock = false;
    String currentCodeLang = '';
    final codeBuffer = StringBuffer();

    // 本文用の追加マージン（PdfGeneratorのページマージンと同じ値を使用）
    final bodyMargin = pw.EdgeInsets.only(
      left: leftMarginMm * PdfPageFormat.mm,
      right: rightMarginMm * PdfPageFormat.mm,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 画像の検出 (｜画像ファイル名.png)
      final imageMatch = RegExp(r'^｜(.*\.(png|jpg|jpeg))$').firstMatch(line.trim());
      if (imageMatch != null && !inCodeBlock) {
        final imageName = imageMatch.group(1)!;
        if (imageCache.containsKey(imageName)) {
          // 後続の「｜」行をカウントして高さを決定
          int heightLines = 1;
          int j = i + 1;
          while (j < lines.length) {
            final nextLine = lines[j].trim();
            if (nextLine == '｜') {
              heightLines++;
              j++;
            } else {
              break;
            }
          }

          widgets.add(pw.Container(
            height: (fontSize + lineSpacing) * heightLines,
            width: useFullWidth ? double.infinity : null,
            margin: bodyMargin,
            alignment: pw.Alignment.center,
            child: pw.Image(imageCache[imageName]!, fit: pw.BoxFit.contain),
          ));

          // 処理した行分スキップ
          i = j - 1;
          continue;
        }
      }

      // コードブロックの判定 (```)
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          // コードブロック終了
          inCodeBlock = false;
          final codeContent = codeBuffer.toString();

          if (codeContent.isNotEmpty) {
            // 改行コードの違い(\r\nなど)を吸収して分割
            final codeLines = codeContent.split(RegExp(r'\r?\n'));
            // writelnによって末尾に余分な空行ができるため、最後が空なら削除
            if (codeLines.isNotEmpty && codeLines.last.isEmpty) {
              codeLines.removeLast();
            }

            for (int i = 0; i < codeLines.length; i++) {
              var lineText = codeLines[i];
              final isFirst = i == 0;
              final isLast = i == codeLines.length - 1;

              widgets.add(pw.Container(
                width: useFullWidth ? double.infinity : null,
                margin: bodyMargin,
                decoration: pw.BoxDecoration(
                  color: PdfColors.black,
                  borderRadius: pw.BorderRadius.vertical(
                    top: isFirst ? const pw.Radius.circular(4.0) : pw.Radius.zero,
                    bottom: isLast ? const pw.Radius.circular(4.0) : pw.Radius.zero,
                  ),
                ),
                padding: pw.EdgeInsets.only(
                  left: 4.0,
                  right: 4.0,
                  top: isFirst ? 4.0 : 1.0,
                  bottom: isLast ? 4.0 : 1.0,
                ),
                child: () {
                  // 空行の場合はSizedBoxで高さを確保（フォント依存を回避）
                  if (lineText.isEmpty) {
                    return pw.SizedBox(height: fontSize);
                  }

                  final indentMatch = RegExp(r'^(\s*)').firstMatch(lineText);
                  final indent = indentMatch?.group(1) ?? '';
                  final trimmedLine = lineText.trimLeft();

                  if (trimmedLine.startsWith('- ')) {
                    return pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // インデントと「- 」を一つの塊として扱い、改行させない
                        pw.Container(child: pw.RichText(
                            text: highlightCode(indent + '- ', currentCodeLang, codeTtf, ttf, fontSize)
                        )),
                        pw.Expanded(
                            child: pw.RichText(
                                text: highlightCode(trimmedLine.substring(2), currentCodeLang, codeTtf, ttf, fontSize)
                            )
                        )
                      ],
                    );
                  } else {
                    return pw.RichText(
                        text: highlightCode(lineText, currentCodeLang, codeTtf, ttf, fontSize)
                    );
                  }
                }(),
              ));
            }
            widgets.add(pw.SizedBox(height: lineSpacing));
          }
          codeBuffer.clear();
        } else {
          // コードブロック開始
          inCodeBlock = true;
          final match = RegExp(r'^```\s*(\w*)').firstMatch(line.trim());
          currentCodeLang = match?.group(1) ?? '';
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      // 空行の場合は、1行分のスペースを空ける
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: fontSize + lineSpacing));
        continue;
      }

      // 水平線の検出 (---)
      if (RegExp(r'^---+$').hasMatch(line.trim())) {
        widgets.add(pw.Container(margin: bodyMargin, child: pw.Divider()));
        continue;
      }

      // 見出し行の検出 (# で始まる行)
      final headerMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(line);
      if (headerMatch != null) {
        final hashes = headerMatch.group(1)!;
        var text = headerMatch.group(2)!;

        if (text == 'index') {
          if (hashes.length == 1) {
            // # index の場合は「目次」というタイトルにする
            text = '目次';
          } else if (hashes.length == 2) {
            // ## index の場合は目次の中身を展開する（見出し自体は出力しない）
            for (final entry in toc) {
              final pageNum = headerPageMap[entry.text];
              final pageStr = pageNum != null ? '$pageNum' : '';

              widgets.add(pw.Container(
                width: useFullWidth ? double.infinity : null,
                margin: pw.EdgeInsets.only(bottom: lineSpacing).add(bodyMargin),
                padding: pw.EdgeInsets.only(left: (entry.level - 1) * fontSize),
                child: pw.Row(
                  children: [
                    pw.Text(
                      entry.text,
                      style: pw.TextStyle(font: ttf, fontSize: fontSize),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      pageStr,
                      style: pw.TextStyle(font: ttf, fontSize: fontSize),
                    ),
                  ],
                ),
              ));
            }
            continue;
          }
        }

        // ## の場合は1.5倍、それ以外は2倍
        final headerFontSize = hashes.length == 2 ? fontSize * 1.5 : fontSize * 2;

        final headerWidget = pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10.0, top: 5.0).add(bodyMargin), // 見出しの上下に少し余白を入れる
          child: pw.Text(
            text,
            style: pw.TextStyle(font: gothicTtf, fontSize: headerFontSize),
          ),
        );

        widgets.add(PageRecorder(
          child: headerWidget,
          onPageRecorded: (page) {
            if (isDryRun) {
              final actualPage = page;
              headerPageMap[text] = actualPage;
            }
          },
        ));
        continue;
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

      spans.addAll(parseRichText(
        textContent,
        ttf: ttf,
        codeTtf: codeTtf,
        gothicTtf: gothicTtf,
        fontSize: fontSize,
      ));

      // 禁則文字セット（行頭に来てはいけない文字）
      const kinsokuChars = {'、', '。', 'っ', 'ゃ', 'ゅ', 'ょ', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'ゎ', 'ヵ', 'ヶ', 'ー', '…', '！', '？', '!', '?', ')', '）', ']', '］', '}', '｝', '」', '』', ',', '.'};

      final builtItems = <BuiltItem>[];

      // 1. すべてのSpanを文字単位のBuiltItemリストに展開
      for (final span in spans) {
        if (span is pw.TextSpan) {
          final text = span.text ?? '';
          final runes = text.runes.toList();
          for (int i = 0; i < runes.length; i++) {
            final rune = runes[i];
            final charStr = String.fromCharCode(rune);

            pw.Widget charWidget;

            if (rune == 0x3000) {
              if (span.style?.font == codeTtf) {
                charWidget = pw.SizedBox(width: fontSize, height: fontSize);
              } else {
                builtItems.add(BuiltItem(pw.SizedBox(width: fontSize, height: fontSize)));
                continue;
              }
            } else if (rune == 0x0020 || rune == 0x0009) {
              if (span.style?.font == codeTtf) {
                charWidget = pw.SizedBox(width: fontSize * 0.5, height: fontSize);
              } else {
                builtItems.add(BuiltItem(pw.SizedBox(width: fontSize * 0.5, height: fontSize)));
                continue;
              }
            } else {
              charWidget = pw.Text(charStr, style: span.style);
            }

            // インラインコードの装飾
            if (span.style?.font == codeTtf) {
              const radius = pw.Radius.circular(4.0);
              final isFirst = i == 0;
              final isLast = i == runes.length - 1;

              charWidget = pw.Container(
                margin: const pw.EdgeInsets.only(top: 0.0),
                padding: const pw.EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                decoration: pw.BoxDecoration(
                  color: PdfColors.black,
                  borderRadius: pw.BorderRadius.horizontal(
                    left: isFirst ? radius : pw.Radius.zero,
                    right: isLast ? radius : pw.Radius.zero,
                  ),
                ),
                child: charWidget,
              );
            }

            builtItems.add(BuiltItem(charWidget, isKinsoku: kinsokuChars.contains(charStr)));
          }
        } else if (span is pw.WidgetSpan) {
          builtItems.add(BuiltItem(span.child));
        }
      }

      // 2. 禁則文字を直前の要素と結合して最終的なWidgetリストを作成
      final finalWidgets = <pw.Widget>[];
      for (final item in builtItems) {
        if (item.isKinsoku && finalWidgets.isNotEmpty) {
          // 禁則文字なら、直前のWidgetを取り出して結合する
          final prev = finalWidgets.removeLast();
          finalWidgets.add(pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [prev, item.widget],
          ));
        } else {
          finalWidgets.add(item.widget);
        }
      }

      widgets.add(pw.Container(
        margin: pw.EdgeInsets.only(bottom: lineSpacing).add(bodyMargin),
        width: useFullWidth ? double.infinity : null,
        child: pw.Wrap(
          runSpacing: lineSpacing,
          children: finalWidgets,
        ),
      ));
    }
    return widgets;
  }
}