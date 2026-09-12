import '../../core/models.dart';

enum ColorMode { auto, always, never }

class TerminalReporter {
  const TerminalReporter._();

  static String render(
    DiagnosticReport report, {
    ColorMode colorMode = ColorMode.auto,
    bool useAscii = false,
    String? commandName,
  }) {
    final useColor =
        colorMode == ColorMode.always || (colorMode == ColorMode.auto);
    final buffer = StringBuffer();

    final lineChar = useAscii ? '-' : '─';
    final divider = lineChar * 60;

    // Title Header
    buffer.writeln(_bold('Flutter Dev Intelligence Diagnostics', useColor));
    buffer.writeln(divider);
    buffer.writeln('${_bold('Project:', useColor)} ${report.projectName}');
    buffer.writeln('${_bold('Report ID:', useColor)} ${report.id}');
    buffer.writeln(
      '${_bold('Generated:', useColor)} ${report.createdAt.toIso8601String()}',
    );
    buffer.writeln();

    // Summary Section
    buffer.writeln(_bold('Summary', useColor));
    buffer.writeln('  Total Findings:      ${report.findings.length}');
    buffer.writeln(
      '  Primary Root Causes: ${_colorStatus(report.primaryFindings.length.toString(), report.primaryFindings.isNotEmpty ? DiagnosticSeverity.error : DiagnosticSeverity.info, useColor)}',
    );
    buffer.writeln('  Cascading Errors:    ${report.cascadingFindings.length}');
    buffer.writeln();

    // Primary Suspected Issues
    if (report.primaryFindings.isNotEmpty) {
      buffer.writeln(_bold('Primary Suspected Issues', useColor));
      buffer.writeln(divider);
      for (final finding in report.primaryFindings) {
        _renderFinding(buffer, finding, useColor: useColor);
      }
    }

    // Cascading / Secondary Findings
    if (report.cascadingFindings.isNotEmpty) {
      buffer.writeln(_bold('Cascading / Secondary Failures', useColor));
      buffer.writeln(divider);
      for (final finding in report.cascadingFindings) {
        _renderFinding(buffer, finding, useColor: useColor);
      }
    }

    // Independent / Other Findings
    if (report.independentFindings.isNotEmpty &&
        report.primaryFindings.isEmpty &&
        report.cascadingFindings.isEmpty) {
      buffer.writeln(_bold('Diagnostic Findings', useColor));
      buffer.writeln(divider);
      for (final finding in report.independentFindings) {
        _renderFinding(buffer, finding, useColor: useColor);
      }
    }

    if (report.findings.isEmpty) {
      buffer.writeln(
        _colorText(
          'No build errors or diagnostic issues detected.',
          '\x1B[32m',
          useColor,
        ),
      );
      buffer.writeln();
    }

    if (report.unrecognizedLogLines.isNotEmpty) {
      buffer.writeln(_bold('Unrecognized Log Output', useColor));
      buffer.writeln(
        '  ${report.unrecognizedLogLines.length} unrecognized log lines observed.',
      );
      buffer.writeln();
    }

    return buffer.toString();
  }

  static void _renderFinding(
    StringBuffer buffer,
    DiagnosticFinding finding, {
    required bool useColor,
  }) {
    buffer.writeln(
      '${_severityBadge(finding.severity, useColor)} ${_bold(finding.title, useColor)} [${finding.id}]',
    );
    buffer.writeln('  Category:   ${finding.category.displayName}');
    buffer.writeln('  Confidence: ${finding.confidence.name.toUpperCase()}');
    if (finding.classificationReason != null) {
      buffer.writeln('  Reason:     ${finding.classificationReason}');
    }
    buffer.writeln();
    buffer.writeln('  ${_bold('Summary:', useColor)} ${finding.summary}');
    buffer.writeln(
      '  ${_bold('Likely Cause:', useColor)} ${finding.likelyCause}',
    );
    buffer.writeln();

    if (finding.evidence.isNotEmpty) {
      buffer.writeln('  ${_bold('Evidence:', useColor)}');
      for (final ev in finding.evidence) {
        buffer.writeln('    - ${ev.label}: ${ev.value}');
      }
      buffer.writeln();
    }

    if (finding.recommendations.isNotEmpty) {
      buffer.writeln('  ${_bold('Recommended Next Steps:', useColor)}');
      for (var i = 0; i < finding.recommendations.length; i++) {
        final rec = finding.recommendations[i];
        buffer.writeln(
          '    ${i + 1}. ${rec.action}${rec.details.isNotEmpty ? " (${rec.details})" : ""}',
        );
      }
      buffer.writeln();
    }
  }

  static String _bold(String text, bool useColor) =>
      useColor ? '\x1B[1m$text\x1B[22m' : text;

  static String _colorText(String text, String colorCode, bool useColor) =>
      useColor ? '$colorCode$text\x1B[0m' : text;

  static String _severityBadge(DiagnosticSeverity severity, bool useColor) {
    if (!useColor) return '[${severity.name.toUpperCase()}]';
    switch (severity) {
      case DiagnosticSeverity.critical:
      case DiagnosticSeverity.error:
        return '\x1B[41m\x1B[37m ERROR \x1B[0m';
      case DiagnosticSeverity.warning:
        return '\x1B[43m\x1B[30m WARN  \x1B[0m';
      case DiagnosticSeverity.info:
        return '\x1B[44m\x1B[37m INFO  \x1B[0m';
    }
  }

  static String _colorStatus(
    String text,
    DiagnosticSeverity severity,
    bool useColor,
  ) {
    if (!useColor) return text;
    switch (severity) {
      case DiagnosticSeverity.critical:
      case DiagnosticSeverity.error:
        return '\x1B[31m$text\x1B[0m';
      case DiagnosticSeverity.warning:
        return '\x1B[33m$text\x1B[0m';
      case DiagnosticSeverity.info:
        return '\x1B[32m$text\x1B[0m';
    }
  }

  static String stripAnsi(String text) {
    return text.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
  }
}
