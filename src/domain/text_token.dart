abstract class TextToken {}

class PlainToken extends TextToken {
  final String text;
  PlainToken(this.text);
}

class BoldToken extends TextToken {
  final String text;
  BoldToken(this.text);
}

class InlineCodeToken extends TextToken {
  final String text;
  InlineCodeToken(this.text);
}

class RubyToken extends TextToken {
  final String base;
  final String ruby;
  RubyToken({required this.base, required this.ruby});
}

class KantenToken extends TextToken {
  final String text;
  KantenToken(this.text);
}
