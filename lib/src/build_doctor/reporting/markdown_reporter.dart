import '../../core/models.dart';

class MarkdownReporter {
  const MarkdownReporter._();

  static String render(DiagnosticReport report) {
    return report.toMarkdown();
  }
}
