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

const _sampleText = '''# index
## index
===page===
# はじめに

　これはマダヨムの機能サンプルです。

## ルビ・圏点

　｜山《やま》に登った。｜山《やまやま》山のように長いルビは自動調整されます。

　｜大切《圏》なことは、｜諦《あきら》めないこと。

## 文字装飾

　**太字**と`インラインコード`が使えます。

---

## コードブロック

```dart
void main() async {
  print('こんにちは');
}
```

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
