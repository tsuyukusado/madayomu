import 'package:pdf/widgets.dart' as pw;

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