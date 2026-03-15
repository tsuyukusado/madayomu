import 'package:test/test.dart';

import 'package:madayomu/src/application/numbering.dart';

void main() {
  group('applyNumbering', () {
    test('#は0から始まる', () {
      final result = applyNumbering('# はじめに');
      expect(result, equals('# 0. はじめに'));
    });

    test('複数の#は連番になる', () {
      final result = applyNumbering('# 一章\n# 二章');
      expect(result, contains('# 0. 一章'));
      expect(result, contains('# 1. 二章'));
    });

    test('##は直前の#の番号を使う', () {
      final result = applyNumbering('# はじめに\n## セクション1');
      expect(result, contains('# 0. はじめに'));
      expect(result, contains('## 0-1. セクション1'));
    });

    test('##は章をまたいでリセットされる', () {
      final result = applyNumbering('# 一章\n## セクション1\n# 二章\n## セクション2');
      expect(result, contains('## 0-1. セクション1'));
      expect(result, contains('## 1-1. セクション2'));
    });

    test('indexという見出しは番号が振られない', () {
      final result = applyNumbering('# index\n# 本文');
      expect(result, contains('# index'));
      expect(result, contains('# 0. 本文'));
    });

    test('コードブロック内の#は無視される', () {
      final result = applyNumbering('# 本文\n```\n# コードの中\n```');
      expect(result, contains('# 0. 本文'));
      expect(result, contains('# コードの中'));
    });
  });
}
