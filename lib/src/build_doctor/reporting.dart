import 'dart:convert';

import '../core/models.dart';

/// Renderers for structured diagnostic output.
class DiagnosticReportRenderer {
  const DiagnosticReportRenderer();

  static String renderTerminal(DiagnosticReport report) {
    final buffer = StringBuffer();
    buffer.writeln('Diagnostic Report: ${report.projectName}');
    buffer.writeln('Issues: ${report.issues.length}');
    if (report.issues.isEmpty) {
      buffer.writeln('No issues detected.');
    } else {
      for (final issue in report.issues) {
        buffer.writeln('- ${issue.title} [${issue.severity.name}]');
        buffer.writeln('  Source: ${issue.source}');
        buffer.writeln('  ${issue.description}');
        if (issue.suggestions.isNotEmpty) {
          buffer.writeln(
            '  Suggested action: ${issue.suggestions.first.action}',
          );
        }
      }
    }

    if (report.warnings.isNotEmpty) {
      buffer.writeln('Warnings: ${report.warnings.join('; ')}');
    }
    if (report.skippedAnalyses.isNotEmpty) {
      buffer.writeln('Skipped: ${report.skippedAnalyses.join(', ')}');
    }
    if (report.unavailableAnalyses.isNotEmpty) {
      buffer.writeln('Unavailable: ${report.unavailableAnalyses.join('; ')}');
    }
    if (report.limitations.isNotEmpty) {
      buffer.writeln('Limitations: ${report.limitations.join('; ')}');
    }
    return buffer.toString();
  }

  static String renderJson(DiagnosticReport report) {
    return const JsonEncoder.withIndent('  ').convert(report.toJson());
  }

  static String renderMarkdown(DiagnosticReport report) {
    return report.toMarkdown();
  }
}
