import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// FileSystem API（webkit prefix）の拡張型定義
@JS()
extension type _FSEntry._(JSObject _) implements JSObject {
  external bool get isFile;
  external bool get isDirectory;
  external String get name;
}

@JS()
extension type _FSFileEntry._(JSObject _) implements _FSEntry {
  external void file(JSFunction success, [JSFunction error]);
}

@JS()
extension type _FSDirectoryEntry._(JSObject _) implements _FSEntry {
  external _FSDirectoryReader createReader();
}

@JS()
extension type _FSDirectoryReader._(JSObject _) implements JSObject {
  external void readEntries(JSFunction success, [JSFunction error]);
}

/// ドロップされたアイテムリストからファイルを再帰的に読み込む
Future<Map<String, Uint8List>> readDroppedItems(web.DataTransferItemList items) async {
  final files = <String, Uint8List>{};
  final futures = <Future<void>>[];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.kind != 'file') continue;
    final entry = item.callMethod<_FSEntry?>('webkitGetAsEntry'.toJS);
    if (entry != null) {
      futures.add(_processEntry(entry, files));
    }
  }

  await Future.wait(futures);
  return files;
}

Future<void> _processEntry(_FSEntry entry, Map<String, Uint8List> files) async {
  if (entry.isFile) {
    final file = await _entryToFile(entry as _FSFileEntry);
    if (file != null) {
      final buffer = await file.arrayBuffer().toDart;
      files[entry.name] = buffer.toDart.asUint8List();
    }
  } else if (entry.isDirectory) {
    final reader = (entry as _FSDirectoryEntry).createReader();
    await _readAll(reader, files);
  }
}

Future<void> _readAll(_FSDirectoryReader reader, Map<String, Uint8List> files) async {
  while (true) {
    final batch = await _readBatch(reader);
    if (batch.isEmpty) break;
    await Future.wait(batch.map((e) => _processEntry(e, files)));
  }
}

Future<List<_FSEntry>> _readBatch(_FSDirectoryReader reader) {
  final completer = Completer<List<_FSEntry>>();
  void onSuccess(JSObject results) {
    final arr = results as JSArray<JSAny?>;
    completer.complete(arr.toDart.cast<_FSEntry>());
  }
  void onError(JSObject _) { completer.complete([]); }
  reader.readEntries(onSuccess.toJS, onError.toJS);
  return completer.future;
}

Future<web.File?> _entryToFile(_FSFileEntry entry) {
  final completer = Completer<web.File?>();
  void onSuccess(web.File f) { completer.complete(f); }
  void onError(JSObject _) { completer.complete(null); }
  entry.file(onSuccess.toJS, onError.toJS);
  return completer.future;
}
