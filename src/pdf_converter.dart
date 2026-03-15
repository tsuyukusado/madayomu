import 'font.dart';
import 'models.dart';
import 'pdf_generator.dart';

// テキストをPDFのバイト列に変換する
Future<List<int>> convertToPdf(NovelContent novel) async {
  final fonts = await loadFonts();
  // 見出しに番号を振る処理
  final linesForNumbering = novel.content.split(RegExp(r'\r?\n'));
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
        sectionCount = 0;
        numberedLines.add('# $chapterCount. ${headerMatch.group(2)!.trim()}');
        chapterCount++;
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
  final content = numberedLines.join('\n');

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

  final generator = PdfGenerator(fonts);

  // 1回目（ページ番号取得用）
  await generator.generate(
    content: content,
    okudukeContent: novel.okuduke,
    toc: toc,
    headerPageMap: headerPageMap,
    isDryRun: true,
  );

  // 2回目（本番出力用）
  return await generator.generate(
    content: content,
    okudukeContent: novel.okuduke,
    toc: toc,
    headerPageMap: headerPageMap,
    isDryRun: false,
  );
}
