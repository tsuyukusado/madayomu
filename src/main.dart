import 'dart:io';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'pdf_generator.dart';

void main() async {
  // 日本語フォントを読み込む
  final fontData = await File('fonts/ShipporiMincho-Regular.ttf').readAsBytes();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  // ゴシック体（太字）フォントを読み込む ※ファイル名は実際の環境に合わせて変更してください
  final gothicFontData = await File('fonts/NotoSansJP-Bold.ttf').readAsBytes();
  final gothicTtf = pw.Font.ttf(gothicFontData.buffer.asByteData());

  // コード用（等幅）フォントを読み込む ※ファイル名は実際の環境に合わせて変更してください
  // 日本語対応の等幅フォント（例: BIZ UDGothic）を使用
  final codeFontData = await File('fonts/BIZUDGothic-Bold.ttf').readAsBytes();
  final codeTtf = pw.Font.ttf(codeFontData.buffer.asByteData());

  final directory = Directory('novel');
  final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
  files.sort((a, b) => a.path.compareTo(b.path));

  final buffer = StringBuffer();
  String? okudukeContent;

  for (final file in files) {
    if (file.path.endsWith('99_okuduke.md')) {
      okudukeContent = await file.readAsString();
      continue;
    }
    buffer.write(await file.readAsString());
    buffer.writeln();
  }
  var content = buffer.toString();

  // 見出しに番号を振る処理
  final linesForNumbering = content.split(RegExp(r'\r?\n'));
  final numberedLines = <String>[];
  int chapterCount = 0;
  int sectionCount = 0;
  bool inCodeBlockForNumbering = false;

  for (final line in linesForNumbering) {
    if (line.trim().startsWith('```')) {
      inCodeBlockForNumbering = !inCodeBlockForNumbering;
      numberedLines.add(line);
      continue;
    }
    if (inCodeBlockForNumbering) {
      numberedLines.add(line);
      continue;
    }

    final headerMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(line);
    if (headerMatch != null && headerMatch.group(2)!.trim() != 'index') {
      final hashes = headerMatch.group(1)!;
      if (hashes.length == 1) {
        chapterCount++;
        sectionCount = 0;
        numberedLines.add('# $chapterCount. ${headerMatch.group(2)!.trim()}');
      } else if (hashes.length == 2) {
        sectionCount++;
        numberedLines.add('## $chapterCount-$sectionCount. ${headerMatch.group(2)!.trim()}');
      } else {
        numberedLines.add(line);
      }
    } else {
      numberedLines.add(line);
    }
  }
  content = numberedLines.join('\n');

  // 目次データの生成
  final toc = <TocEntry>[];
  final allLines = content.split(RegExp(r'\r?\n'));
  bool inCodeBlock = false;
  for (final line in allLines) {
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

  // ページ番号マップ
  final headerPageMap = <String, int>{};

  final generator = PdfGenerator(ttf, gothicTtf, codeTtf);

  // 1回目（ページ番号取得用）
  await generator.generate(
    content: content,
    okudukeContent: okudukeContent,
    toc: toc,
    headerPageMap: headerPageMap,
    isDryRun: true,
  );

  // 2回目（本番出力用）
  final bytes = await generator.generate(
    content: content,
    okudukeContent: okudukeContent,
    toc: toc,
    headerPageMap: headerPageMap,
    isDryRun: false,
  );
  
  final file = File('test.pdf');
  await file.writeAsBytes(bytes);
  print('PDFができたぜ！');
}