import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

import 'web_drop.dart';
import 'infrastructure/flutter_pdf_renderer.dart';
import 'src/application/converter.dart';
import 'src/domain/models.dart';

// ブラウザのTextDecoder API（Shift-JISなど多様な文字コードに対応）
@JS('TextDecoder')
extension type _TextDecoder._(JSObject _) implements JSObject {
  external factory _TextDecoder(String encoding);
  external String decode(JSObject buffer);
}

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


class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  TextSelection _savedSelection = const TextSelection.collapsed(offset: 0);
  bool _isLoading = false;
  String? _errorMessage;

  static const _sampleText = '''# はじめに
\u3000この文章では、マダヨムの使い方を解説いたします。
\u3000マダヨムは、マークダウン記法とカクヨム記法を組み合わせたPDF生成ツールです。
\u3000以下の手順で文章を執筆することで、簡単に印刷、電子書籍出版可能なPDFを作ることが出来ます。
\u3000まずは上記のPDF生成ボタンをクリックし、この文章をPDFに変換してみてください。
===page===
# index
## index
===page===
# まずは文章を執筆しよう
\u3000まずは自由に、あなたの思い通りの文章を書きましょう。

\u3000本を作るには、文章が必要です。
\u3000
\u3000また、本文の中に挿入したい画像があれば、それも保管し、分かりやすい名前をつけておきましょう。そして、画像を挿入したい箇所が分かるようにしておきましょう。
===page===
# 一度生成してみよう
\u3000原稿が完成したら（未完成でも試してみるのも良いと思います）マダヨムを開きます。
\u3000そして、以下のどちらかの手順で、原稿を読み込ませます。

---

①テキストをコピー＆ペースト
②`.md`または`.txt`、またはそれらの入ったフォルダをドラッグ＆ドロップ

---

\u3000この段階で、一度PDFを生成してみてください。
\u3000これでおおよその土台は出来上がっています。

\u3000しかし、実際に印刷するにあたっては、様々な組版をしたいのではないかと思います。（組版：印刷するために整えること）
\u3000そこで以下では、このツールで対応している様々な組版手段や装飾を解説していきます。
===page===
# 組版・装飾の仕方
\u3000目次を参考に、自分が行いたい組版、装飾の項目を確認してください。
\u3000なお、これらの記法は、マダヨム上部のボタンから挿入することが可能です。
===page===
## 自分の好みの位置で改ページしたい
\u3000改ページの記法は、

`===page===`

\u3000です。
\u3000この記法を文章の行と行の合間に挿入すると、その次の行から新しいページになります。

## 見出しをつけたい
\u3000見出しの記法は、

`# ここに大見出しを書く`

\u3000または

`## ここに小見出しを書く`

\u3000です、

\u3000見出しの文章は、**ゴシック体の太字**になり、大きくなります。
\u3000シャープが１つだと大見出し、２つだと小見出しになります。シャープの後には、半角スペースを入れましょう。

===page===
## 目次が欲しい
\u3000本には目次が必須です。
\u3000目次を生成したい場合、**見出しが必要**です。上記の見出しを必ず入れるようにしてください（目次は、見出しを抽出して表示するため）。
\u3000まず、**目次**というタイトルを入れます。
\u3000目次というタイトルを入れる記法は

`# index`

\u3000です。

\u3000その下に、目次本文を出力します。
\u3000目次本文を出力するコードは

`## index`

\u3000です。
\u3000これによって生成されるのは、各見出しのページ数が書かれた見出しの一覧表です。
\u3000このPDFテキストの、**はじめに**の後に表示されていた**目次**というページがそれに該当します。
===page===
## 奥付を入れたい
\u3000本を出版するのなら、やはり奥付も欲しいですよね。
\u3000奥付を挿入する記法は、

`# okuduke`

\u3000です。
\u3000この記法を挿入した次の行から、奥付として**下揃え**になります。
\u3000なお、奥付は最終ページに挿入することを想定しています。冒頭や中間等のページには作成しないでください。
\u3000また、奥付は直前の本文と同じページに挿入することは出来ません。
\u3000必ず、上記の改ページ記法を直前に挟んでください。
===page===
## 字下げ（インデント）をしたい
\u3000日本語の文章では、段落の先頭を一文字分下げるのが一般的です。
\u3000マダヨムでは、行頭に全角スペースを入れることで字下げができます。

`\u3000ここから文章を書く`

\u3000全角スペース一つで一文字分、半角スペース一つで半文字分のインデントになります。
\u3000このマニュアルの本文も、すべて全角スペース一つで字下げしています。
===page===
## カクヨム記法でルビを振りたい
\u3000カクヨム記法をご存知の方には、説明する必要はありません。
\u3000**そのままの記法で入力すれば、自動で変換されます。**
\u3000ご存知でない方に向けて解説すると、カクヨムではルビはこのように入力します。

`｜漢字《ルビ》`

\u3000この記法に合わせて入力することで、漢字の上部に小さくふりがなが振られます。

## ついでに圏点も入れたい
\u3000カクヨムで圏点を入れたい場合、一文字ずつ点を書く必要がありました。
\u3000しかし、マダヨムではそれを簡略化しています。
\u3000記法はこちらです。

`｜圏点を入れたい文章《圏》`

\u3000この用に入力することで、圏点を挿入可能です。
===page===
## 太字にしたい
\u3000文章の中で、特に強調したい言葉を太字にすることができます。
\u3000記法はこちらです。

`**太字にしたい文章**`

\u3000このように、アスタリスク二つで強調したい文章の前後を挟みます。
\u3000太字はゴシック体で表示されます。見出しとは異なり、文字サイズは変わりません。
===page===
## インラインコードを使いたい
\u3000このマニュアルでも多用していますが、文章の中に短いコードや特殊な記法をそのまま表示したい場合、インラインコードが使えます。
\u3000記法を表示したいのですが、変換されてしまうため実際に書くことが出来ません。

`(バッククォート)インラインコードに入れたい文章(バッククォート)`
\u3000バッククォートという記号で前後を挟むことで、黒背景のコード表示になります。
\u3000詳細は、このPDFが生成される前のテキストを見てください。
\u3000文章の中に目立たせたい語句を入れる際にも使えます。
===page===
## コードブロックを使いたい
\u3000複数行にわたるコードを表示したい場合は、コードブロックを使います。
\u3000この記法も、インラインコードと同様に正常に表示することが出来ないため、文字にして解説します。こちらです。

```
(バッククォート３つ)
ここにコードを書く
複数行書いても大丈夫
(バッククォート3つ)
```

\u3000バッククォート三つで囲むことで、黒背景のブロック表示になります。
\u3000また、一行目のバッククォート３つの後に言語名を書くことで、シンタックスハイライトに対応します。

```dart
void main() {
  print('Hello, Madayomu!');
}
```

\u3000現在シンタックスハイライトに対応しているのは、`dart`と`md`（マークダウン）です。
===page===
## 水平線を入れたい
\u3000章の区切りなどに、横線を入れることができます。
\u3000記法はこちらです。

`---`

\u3000ハイフン三つを単独の行に書くことで、水平線が表示されます。
\u3000このマニュアルの冒頭でも、手順の区切りとして使用しています。
===page===
## 画像を挿入したい
\u3000本文中に画像を挿入することができます。
\u3000まず、画像ファイル（`.png`・`.jpg`・`.jpeg`）を原稿と一緒にドラッグ＆ドロップで読み込んでください。
\u3000その上で、挿入したい箇所に以下の記法を書きます。

`｜画像ファイル名.png`

\u3000縦棒`｜`の後に、ファイル名を拡張子ごと書きます。
\u3000また、画像の表示高さは、その直後に`｜`だけの行を続けることで調整できます。

```
｜画像ファイル名.png
｜
｜
```

\u3000上記の場合、`｜`が三行分あるので、3行分の高さで画像が表示されます。
===page===
# 最後に
\u3000上述の機能以外にも、マダヨムは今後もアップデートを重ねていく予定です。
\u3000ご意見やご要望は、お気軽にわたしのDMや、`kureyon@tsuyukusado.com`までお寄せください。
===page===
# okuduke
**これは、奥付のサンプルです。**

---

執筆者；露草くれよん
更新日：2026年3月22日''';

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
    _controller.addListener(_saveSelection);
  }

  void _saveSelection() {
    final sel = _controller.selection;
    if (sel.start >= 0) _savedSelection = sel;
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
    _controller.removeListener(_saveSelection);
    _controller.dispose();
    _focusNode.dispose();
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

  Future<void> _generatePdf({bool isPrint = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = _isFolderMode
          ? await _generateFromFiles(isPrint: isPrint)
          : await _generateFromText(isPrint: isPrint);
      _downloadPdf(bytes);
    } catch (e) {
      setState(() => _errorMessage = 'エラーが発生しました: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<int>> _generateFromText({bool isPrint = false}) async {
    final text = _controller.text.trim();
    if (text.isEmpty) throw Exception('テキストが空です');
    final novel = extractOkuduke(text);
    return convertToPdf(novel, _makeRenderer(isPrint));
  }

  FlutterPdfRenderer _makeRenderer(bool isPrint) => isPrint
      ? FlutterPdfRenderer(leftMarginMm: 18, rightMarginMm: 7, isPrint: true)
      : FlutterPdfRenderer();

  Future<List<int>> _generateFromFiles({bool isPrint = false}) async {
    // .mdファイルをファイル名でソート
    final mdFiles = _droppedFiles.entries
        .where((e) => e.key.endsWith('.md') || e.key.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (mdFiles.isEmpty) throw Exception('.mdファイルが見つかりません');

    // 全ファイルを結合し、# okuduke セクションを奥付として抽出
    final buffer = StringBuffer();
    for (final f in mdFiles) {
      buffer.write(_decodeText(f.value));
      buffer.writeln();
    }
    final novel = extractOkuduke(buffer.toString());

    // 画像ファイルを抽出
    final imageData = {
      for (final e in _droppedFiles.entries)
        if (e.key.endsWith('.png') || e.key.endsWith('.jpg') || e.key.endsWith('.jpeg'))
          e.key: e.value,
    };

    return convertToPdf(novel, _makeRenderer(isPrint), imageData: imageData);
  }

  // UTF-8 / UTF-16 LE / UTF-16 BE に対応したテキストデコード
  String _decodeText(Uint8List bytes) {
    // UTF-8 BOM: EF BB BF
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(Uint8List.sublistView(bytes, 3), allowMalformed: true);
    }
    // UTF-16 LE BOM: FF FE
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _browserDecode(bytes, 'utf-16le');
    }
    // UTF-16 BE BOM: FE FF
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _browserDecode(bytes, 'utf-16be');
    }
    // UTF-8として試みる（失敗したらShift-JISにフォールバック）
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return _browserDecode(bytes, 'shift-jis');
    }
  }

  // ブラウザのTextDecoder APIを使ってデコード
  String _browserDecode(Uint8List bytes, String encoding) {
    try {
      final decoder = _TextDecoder(encoding);
      return decoder.decode(bytes.buffer.toJS);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  void _downloadPdf(List<int> bytes) {
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _isLoading ? null : () => _generatePdf(),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('PDF生成（電子用）'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _isLoading ? null : () => _generatePdf(isPrint: true),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('PDF生成（印刷用）'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFormatButtons(),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: _isFolderMode ? _buildFileList() : _buildTextInput(),
            ),
            Row(
              children: [
                if (!_isFolderMode)
                  TextButton(
                    onPressed: () {
                      _controller.text = _sampleText;
                      _savedSelection = const TextSelection.collapsed(offset: 0);
                    },
                    child: const Text('サンプル文章を挿入する'),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: _showHelp,
                  tooltip: '使い方',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使い方'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              _HelpSection('入力方法', [
                '・テキストをコピペしてエリアに貼り付け',
                '・.txt / .md ファイルをまとめたフォルダをドロップ',
                '　└ 画像（.png / .jpg）を同じフォルダに入れると挿入可',
                '　└ ファイル名の先頭を 01, 02... にすると順番通りに結合',
              ]),
              SizedBox(height: 12),
              _HelpSection('記法', [
                '｜漢字《よみ》　　ルビ',
                '｜文字《圏》　　　圏点',
                '**太字**　　　　　太字',
                '===page===　　　ページ区切り',
                '---　　　　　　　水平線',
                '# index　　　　　目次（見出し自動収集）',
                '## index　　　　 目次の本文',
                '`コード`　　　　  インラインコード',
                '```dart ... ```　コードブロック',
              ]),
              SizedBox(height: 12),
              _HelpSection('ダウンロード', [
                '電子用：余白均等、画面閲覧向け',
                '印刷用：左右余白非対称、製本向け',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButtons() {
    const buttons = [
      '太字',
      'ルビ',
      '圏点',
      '大見出し',
      '小見出し',
      '目次',
      '改ページ',
      '水平線',
      '画像',
      'インラインコード',
      'コードブロック',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in buttons)
          OutlinedButton(
            onPressed: _isFolderMode ? null : () => _applyFormat(label),
            child: Text(label),
          ),
      ],
    );
  }

  void _applyFormat(String label) {
    // フォーカスが外れている場合、保存した選択位置を復元してから適用
    final sel = _savedSelection;
    if (sel.start < 0) return;
    switch (label) {
      case '太字':          _wrapInline('**', '**', sel);
      case 'ルビ':          _insertRuby(sel);
      case '圏点':          _insertKenten(sel);
      case '大見出し':       _insertLinePrefix('# ', sel);
      case '小見出し':       _insertLinePrefix('## ', sel);
      case '目次':          _insertBlock('# index\n## index', sel);
      case '改ページ':       _insertBlock('===page===', sel);
      case '水平線':         _insertBlock('---', sel);
      case '画像':          _insertImage(sel);
      case 'インラインコード': _wrapInline('`', '`', sel);
      case 'コードブロック':  _insertCodeBlock(sel);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _wrapInline(String before, String after, TextSelection sel) {
    final text = _controller.text;
    final selected = text.substring(sel.start, sel.end);
    final newText = text.replaceRange(sel.start, sel.end, '$before$selected$after');
    final cursor = sel.isCollapsed
        ? sel.start + before.length
        : sel.start + before.length + selected.length + after.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  void _insertRuby(TextSelection sel) {
    final text = _controller.text;
    if (sel.isCollapsed) {
      _controller.value = TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, '｜《》'),
        selection: TextSelection.collapsed(offset: sel.start + 1),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      final insert = '｜$selected《》';
      _controller.value = TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, insert),
        selection: TextSelection.collapsed(offset: sel.start + 1 + selected.length + 1),
      );
    }
  }

  void _insertKenten(TextSelection sel) {
    final text = _controller.text;
    if (sel.isCollapsed) {
      _controller.value = TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, '｜《圏》'),
        selection: TextSelection.collapsed(offset: sel.start + 1),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      final insert = '｜$selected《圏》';
      _controller.value = TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, insert),
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      );
    }
  }

  void _insertLinePrefix(String prefix, TextSelection sel) {
    final text = _controller.text;
    final lineStart = _findLineStart(text, sel.start);
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + prefix.length),
    );
  }

  int _findLineStart(String text, int pos) {
    if (pos == 0) return 0;
    final idx = text.lastIndexOf('\n', pos - 1);
    return idx == -1 ? 0 : idx + 1;
  }

  void _insertBlock(String content, TextSelection sel) {
    final text = _controller.text;
    final pos = sel.isCollapsed ? sel.start : sel.end;
    final needBefore = pos > 0 && text[pos - 1] != '\n';
    final insert = '${needBefore ? '\n' : ''}$content\n';
    _controller.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, insert),
      selection: TextSelection.collapsed(offset: sel.start + insert.length),
    );
  }

  void _insertImage(TextSelection sel) {
    final text = _controller.text;
    final pos = sel.isCollapsed ? sel.start : sel.end;
    final needBefore = pos > 0 && text[pos - 1] != '\n';
    final prefix = needBefore ? '\n' : '';
    final insert = '$prefix｜\n｜\n｜\n';
    _controller.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, insert),
      selection: TextSelection.collapsed(offset: sel.start + prefix.length + 1),
    );
  }

  void _insertCodeBlock(TextSelection sel) {
    final text = _controller.text;
    final pos = sel.isCollapsed ? sel.start : sel.end;
    final needBefore = pos > 0 && text[pos - 1] != '\n';
    final selected = sel.isCollapsed ? '' : text.substring(sel.start, sel.end);
    final insert = '${needBefore ? '\n' : ''}```\n$selected\n```\n';
    final cursorOffset = sel.start + (needBefore ? 1 : 0) + 4;
    _controller.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, insert),
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  Widget _buildTextInput() {
    return Stack(
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'コピペ or ドラッグ＆ドロップ',
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
    final mdCount = files.where((f) => f.endsWith('.md') || f.endsWith('.txt')).length;
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

class _HelpSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _HelpSection(this.title, this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...items.map((item) => Text(item, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
