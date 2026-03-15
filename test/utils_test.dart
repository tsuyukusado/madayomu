import 'package:test/test.dart';

import 'package:madayomu/src/domain/text_token.dart';
import 'package:madayomu/src/infrastructure/utils.dart';

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

    test('一文字のルビはそのままRubyTokenになる', () {
      final tokens = parseTokens('｜山《やま》');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<RubyToken>());
      final token = tokens[0] as RubyToken;
      expect(token.base, equals('山'));
      expect(token.ruby, equals('やま'));
    });

    test('複数文字のベースは一文字ずつのRubyTokenに分割される', () {
      final tokens = parseTokens('｜漢字《かんじ》');
      expect(tokens.length, equals(2));
      expect(tokens[0], isA<RubyToken>());
      expect(tokens[1], isA<RubyToken>());
      expect((tokens[0] as RubyToken).base, equals('漢'));
      expect((tokens[1] as RubyToken).base, equals('字'));
    });


    test('圏点はKantenTokenになる', () {
      final tokens = parseTokens('｜強調《圏》');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<KantenToken>());
      expect((tokens[0] as KantenToken).text, equals('強調'));
    });

    test('ルビが3文字以上で隣にプレーンテキストがある場合、吸収して再配分される', () {
      final tokens = parseTokens('｜山《やまや》山');
      expect(tokens.length, equals(2));
      expect((tokens[0] as RubyToken).base, equals('山'));
      expect((tokens[0] as RubyToken).ruby, equals('やま'));
      expect((tokens[1] as RubyToken).base, equals('山'));
      expect((tokens[1] as RubyToken).ruby, equals('や\u3000')); // 全角スペースで補填
    });

    test('ルビが3文字以上で隣にプレーンテキストがない場合、警告を出してそのまま返す', () {
      final tokens = parseTokens('｜山《やまや》');
      expect(tokens.length, equals(1));
      expect(tokens[0], isA<RubyToken>());
      expect((tokens[0] as RubyToken).base, equals('山'));
      expect((tokens[0] as RubyToken).ruby, equals('やまや'));
    });

    test('混在したテキストは複数のTokenに分解される', () {
      final tokens = parseTokens('これは｜漢字《かんじ》で**太字**の文章だ');
      expect(tokens.length, equals(6));
      expect(tokens[0], isA<PlainToken>());
      expect(tokens[1], isA<RubyToken>());
      expect(tokens[2], isA<RubyToken>());
      expect(tokens[3], isA<PlainToken>());
      expect(tokens[4], isA<BoldToken>());
      expect(tokens[5], isA<PlainToken>());
    });
  });
}
