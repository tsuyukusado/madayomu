import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

import 'web_drop.dart';
import 'infrastructure/flutter_pdf_renderer.dart';
import 'src/application/converter.dart';
import 'src/domain/models.dart';

void main() {
  runApp(const MadayomuApp());
}

class MadayomuApp extends StatelessWidget {
  const MadayomuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'madayomu',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

const _sampleText = '''# とりあえずやってみよう
　まず初めに、一番下の**PDFを作る**というボタンをクリックしてください。
　すると、このようなPDFが生成されます。
===page===
# index
## index
===page===
# はじめに
　これはマダヨムのサンプル文章です。このツールは、テキストをコピペしてワンクリックすることで、簡単にPDFを生成できます。

---

## ルビ・圏点
　ルビとは、文字の上に書かれるふりがなのことです。

　｜創造《そうぞう》は、きみを｜楽《らく》にする。

　なお、このような｜極端《きょくたんすぎるがおためしで》なルビも入力することが可能です。
　｜圏点とは《圏》、｜文字の上に書かれる点のことです《圏》。

---

## 文字装飾
　文字を**太字**にすることが出来ます。

---
## 全体装飾
　`# index`と入力すると、「目次」という見出しが表示されます。
　`## index`と入力すると、目次の本文を表示します。
　目次の本文は、`#`または`##`で入力した行を自動的に抽出して表示します。また、右端には該当のページ数が表示されます。
　`---`と入力すると、水平線が表示されます。
===page===
# 技術書向け
　以下の機能は、技術書を書かれる方向けの機能です。

---

## インラインコード
　このように、`インラインコード`の入力が出来ます。

---

## コードブロック
```dart
void main() async {
  print('こんにちは');
}
```
　上記のように、コードブロックの入力ができます。
　シンタックスハイライトは、現在**dart**、**markdown**のみ対応しています。

===page===
# おわりに

　以上が主な機能です。''';

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController(text: _sampleText);
  bool _isLoading = false;
  String? _errorMessage;

  // フォルダモード用
  bool _isFolderMode = false;
  Map<String, Uint8List> _droppedFiles = {};
  bool _isDragOver = false;

  // ドラッグイベントリスナー（dispose時に解除するため保持）
  late final JSFunction _onDragOver;
  late final JSFunction _onDragLeave;
  late final JSFunction _onDrop;

  @override
  void initState() {
    super.initState();
    _setupDropListeners();
  }

  void _setupDropListeners() {
    _onDragOver = ((web.Event e) {
      e.preventDefault();
      if (!_isDragOver && mounted) setState(() => _isDragOver = true);
    }).toJS;

    _onDragLeave = ((web.DragEvent e) {
      // relatedTargetがnull＝ブラウザウィンドウの外に出た
      if (e.relatedTarget == null && _isDragOver && mounted) {
        setState(() => _isDragOver = false);
      }
    }).toJS;

    _onDrop = ((web.DragEvent e) {
      e.preventDefault();
      if (mounted) setState(() => _isDragOver = false);
      _handleDrop(e);
    }).toJS;

    web.document.addEventListener('dragover', _onDragOver);
    web.document.addEventListener('dragleave', _onDragLeave);
    web.document.addEventListener('drop', _onDrop);
  }

  @override
  void dispose() {
    web.document.removeEventListener('dragover', _onDragOver);
    web.document.removeEventListener('dragleave', _onDragLeave);
    web.document.removeEventListener('drop', _onDrop);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDrop(web.DragEvent event) async {
    final items = event.dataTransfer?.items;
    if (items == null || items.length == 0) return;

    final files = await readDroppedItems(items);
    if (files.isEmpty) return;

    setState(() {
      _isFolderMode = true;
      _droppedFiles = files;
    });
  }

  void _clearFolderMode() {
    setState(() {
      _isFolderMode = false;
      _droppedFiles = {};
    });
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = _isFolderMode
          ? await _generateFromFiles()
          : await _generateFromText();
      _downloadPdf(bytes);
    } catch (e) {
      setState(() => _errorMessage = 'エラーが発生しました: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<int>> _generateFromText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) throw Exception('テキストが空です');
    final novel = NovelContent(text, null);
    return convertToPdf(novel, FlutterPdfRenderer());
  }

  Future<List<int>> _generateFromFiles() async {
    // .mdファイルをファイル名でソート
    final mdFiles = _droppedFiles.entries
        .where((e) => e.key.endsWith('.md') || e.key.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (mdFiles.isEmpty) throw Exception('.mdファイルが見つかりません');

    // 本文と奥付を分けて結合
    final buffer = StringBuffer();
    String? okuduke;
    for (final f in mdFiles) {
      final text = utf8.decode(f.value);
      if (f.key.contains('99_okuduke')) {
        okuduke = text;
      } else {
        buffer.write(text);
        buffer.writeln();
      }
    }

    // 画像ファイルを抽出
    final imageData = {
      for (final e in _droppedFiles.entries)
        if (e.key.endsWith('.png') || e.key.endsWith('.jpg') || e.key.endsWith('.jpeg'))
          e.key: e.value,
    };

    final novel = NovelContent(buffer.toString(), okuduke);
    return convertToPdf(novel, FlutterPdfRenderer(), imageData: imageData);
  }

  void _downloadPdf(List<int> bytes) {
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = 'output.pdf'
      ..click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マダヨム〜PDFつくーる〜')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _isFolderMode ? _buildFileList() : _buildTextInput(),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red)),
              ),
            Row(
              children: [
                if (_isFolderMode) ...[
                  OutlinedButton(
                    onPressed: _isLoading ? null : _clearFolderMode,
                    child: const Text('テキスト入力に戻る'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _generatePdf,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('PDFつくーる'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Stack(
      children: [
        TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'ここにテキストを貼り付け、またはフォルダをドロップ',
            border: OutlineInputBorder(),
          ),
        ),
        if (_isDragOver)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'フォルダをドロップ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileList() {
    final files = _droppedFiles.keys.toList()..sort();
    final mdCount = files.where((f) => f.endsWith('.md')).length;
    final imgCount = files.where((f) =>
        f.endsWith('.png') || f.endsWith('.jpg') || f.endsWith('.jpeg')).length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '読み込んだファイル：テキスト $mdCount 件、画像 $imgCount 件',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (ctx, i) {
                final name = files[i];
                final isMd = name.endsWith('.md');
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isMd ? Icons.article_outlined : Icons.image_outlined,
                    size: 18,
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
