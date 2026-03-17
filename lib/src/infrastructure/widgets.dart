import 'package:pdf/widgets.dart' as pw;

/// ページ跨ぎを禁止するラッパー。
/// MultiPage でこのウィジェットが1ページに収まらない場合、丸ごと次ページに移動する。
class NoSpanWidget extends pw.SingleChildWidget {
  NoSpanWidget({required pw.Widget child}) : super(child: child);

  @override
  bool get canSpan => false;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class PageRecorder extends pw.SingleChildWidget {
  PageRecorder({
    required pw.Widget child,
    required this.onPageRecorded,
    this.isAtomic = false,
  }) : super(child: child);

  final void Function(int pageNumber) onPageRecorded;
  final bool isAtomic;

  @override
  bool get canSpan => isAtomic ? false : super.canSpan;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
    onPageRecorded(context.pageNumber);
  }
}