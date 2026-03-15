import 'dart:typed_data';

import '../../domain/models.dart';

// 「PDFを作って」という命令の窓口（インターフェース）
// 将来FlutterやWebに対応するときは、この窓口を実装した別クラスを差し込む
abstract class IPdfRenderer {
  Future<List<int>> render(
    String content,
    String? okuduke,
    List<TocEntry> toc, {
    Map<String, Uint8List> imageData = const {},
  });
}
