import 'package:pdf/widgets.dart' as pw;

class PageRecorder extends pw.SingleChildWidget {
  PageRecorder({
    required pw.Widget child,
    required this.onPageRecorded,
  }) : super(child: child);

  final void Function(int pageNumber) onPageRecorded;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
    onPageRecorded(context.pageNumber);
  }
}