import 'package:test/test.dart';

import '../src/text_token.dart';
import '../src/utils.dart';

void main() {
  group('parseTokens', () {
    test('プレーンテキストはPlainTokenになる', () {
      final tokens = parseTokens('ふつうの文章');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<PlainToken>());
      expect((tokens[0] as PlainToken).text, equals('ふつうの文章'));
    });

    test('太字はBoldTokenになる', () {
      final tokens = parseTokens('**太字**');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<BoldToken>());
      expect((tokens[0] as BoldToken).text, equals('太字'));
    });

    test('インラインコードはInlineCodeTokenになる', () {
      final tokens = parseTokens('`code`');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<InlineCodeToken>());
      expect((tokens[0] as InlineCodeToken).text, equals('code'));
    });

    test('ルビはRubyTokenになる', () {
      final tokens = parseTokens('｜漢字《かんじ》');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<RubyToken>());
      final token = tokens[0] as RubyToken;
      expect(token.base, equals('漢字'));
      expect(token.ruby, equals('かんじ'));
    });

    test('三文字以上のルビもRubyTokenになる', () {
      final tokens = parseTokens('｜不思議《ふしぎ》');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<RubyToken>());
      final token = tokens[0] as RubyToken;
      expect(token.base, equals('不思議'));
      expect(token.ruby, equals('ふしぎ'));
    });

    test('圏点はKantenTokenになる', () {
      final tokens = parseTokens('｜強調《圏》');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<KantenToken>());
      expect((tokens[0] as KantenToken).text, equals('強調'));
    });

    test('混在したテキストは複数のTokenに分解される', () {
      final tokens = parseTokens('これは｜漢字《かんじ》で**太字**の文章だ');
      expect(tokens.length, equals(5));
      expect(tokens[0], isA<PlainToken>());
      expect(tokens[1], isA<RubyToken>());
      expect(tokens[2], isA<PlainToken>());
      expect(tokens[3], isA<BoldToken>());
      expect(tokens[4], isA<PlainToken>());
    });
  });
}
