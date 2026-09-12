import '../core/models.dart';
import 'reporting/terminal_reporter.dart';
import 'reporting/json_reporter.dart';
import 'reporting/markdown_reporter.dart';

export 'reporting/terminal_reporter.dart';
export 'reporting/json_reporter.dart';
export 'reporting/markdown_reporter.dart';

class DiagnosticReportRenderer {
  static String renderTerminal(
    DiagnosticReport report, {
    ColorMode colorMode = ColorMode.auto,
    String? commandName,
    bool useAscii = false,
  }) {
    return TerminalReporter.render(
      report,
      colorMode: colorMode,
      useAscii: useAscii,
      commandName: commandName,
    );
  }

  static String renderJson(DiagnosticReport report) {
    return JsonReporter.render(report);
  }

  static String renderMarkdown(DiagnosticReport report) {
    return MarkdownReporter.render(report);
  }

  static String stripAnsi(String text) {
    return TerminalReporter.stripAnsi(text);
  }
}
