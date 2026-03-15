import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';

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

  Future<void> _generatePdf() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final novel = NovelContent(text, null);
      final renderer = FlutterPdfRenderer();
      final bytes = await convertToPdf(novel, renderer);

      // ブラウザでPDFをダウンロードする
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
    } catch (e) {
      setState(() => _errorMessage = 'エラーが発生しました: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('madayomu')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'ここにMarkdownを貼り付けてください',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _isLoading ? null : _generatePdf,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('PDFを作る'),
            ),
          ],
        ),
      ),
    );
  }
}
