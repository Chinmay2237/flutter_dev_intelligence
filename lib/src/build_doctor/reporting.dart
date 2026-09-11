import 'dart:convert';
import 'dart:io';

import '../core/models.dart';

/// Color output behavior for terminal rendering.
enum ColorMode { auto, always, never }

/// Renderers for structured diagnostic output.
class DiagnosticReportRenderer {
  const DiagnosticReportRenderer();

  /// Regular expression to match ANSI escape codes.
  static final RegExp ansiRegex = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');

  /// Strips ANSI escape codes from string.
  static String stripAnsi(String text) {
    return text.replaceAll(ansiRegex, '');
  }

  /// Determines if color formatting should be active.
  static bool isColorEnabled(
    ColorMode mode, {
    bool? isTtyOverride,
    Map<String, String>? environment,
  }) {
    if (mode == ColorMode.never) return false;
    if (mode == ColorMode.always) return true;

    final env = environment ?? Platform.environment;
    final noColor = env['NO_COLOR'];
    if (noColor != null && noColor.isNotEmpty) {
      return false;
    }

    final isTty = isTtyOverride ?? (stdout.hasTerminal);
    return isTty;
  }

  static String renderTerminal(
    DiagnosticReport report, {
    ColorMode colorMode = ColorMode.auto,
    String? commandName,
    bool? isTtyOverride,
  }) {
    final useColor = isColorEnabled(colorMode, isTtyOverride: isTtyOverride);

    String style(String text, String code) =>
        useColor ? '\x1B[${code}m$text\x1B[0m' : text;

    String bold(String text) => style(text, '1');
    String dim(String text) => style(text, '2');
    String cyan(String text) => style(text, '36');
    String yellow(String text) => style(text, '33');
    String green(String text) => style(text, '32');
    String boldRed(String text) => style(text, '1;31');
    String boldYellow(String text) => style(text, '1;33');
    String boldCyan(String text) => style(text, '1;36');

    final buffer = StringBuffer();

    // Tool Header
    buffer.writeln(bold('Flutter Dev Intelligence'));
    buffer.writeln(dim('────────────────────────────────────────────'));

    // Project Metadata
    buffer.writeln('${bold('Project')}     ${report.projectName}');
    if (commandName != null && commandName.isNotEmpty) {
      buffer.writeln('${bold('Command')}     $commandName');
    }
    if (report.durationMs != null) {
      buffer.writeln('${bold('Duration')}    ${report.durationMs} ms');
    }
    buffer.writeln();

    // Summary Section
    buffer.writeln(bold('Summary'));
    buffer.writeln(dim('────────────────────────────────────────────'));
    final totalIssues = report.issues.length;
    final highCount =
        (report.severityCounts['high'] ?? 0) +
        (report.severityCounts['critical'] ?? 0);
    final mediumCount = report.severityCounts['medium'] ?? 0;
    final lowCount =
        (report.severityCounts['low'] ?? 0) +
        (report.severityCounts['info'] ?? 0);
    final warningCount = report.warnings.length;

    buffer.writeln('  ${bold('Issues')}       $totalIssues');
    buffer.writeln(
      '  ${bold('High')}         ${highCount > 0 ? boldRed(highCount.toString()) : highCount.toString()}',
    );
    buffer.writeln(
      '  ${bold('Medium')}       ${mediumCount > 0 ? yellow(mediumCount.toString()) : mediumCount.toString()}',
    );
    buffer.writeln('  ${bold('Low')}          $lowCount');
    if (warningCount > 0) {
      buffer.writeln(
        '  ${bold('Warnings')}     ${yellow(warningCount.toString())}',
      );
    }
    buffer.writeln();

    // Issues Section
    if (report.issues.isNotEmpty) {
      buffer.writeln(bold('Issues'));
      buffer.writeln(dim('────────────────────────────────────────────'));
      buffer.writeln();

      for (final issue in report.issues) {
        String severityLabel;
        switch (issue.severity) {
          case DiagnosticSeverity.critical:
          case DiagnosticSeverity.high:
            severityLabel = boldRed('HIGH');
            break;
          case DiagnosticSeverity.medium:
            severityLabel = boldYellow('MEDIUM');
            break;
          case DiagnosticSeverity.low:
          case DiagnosticSeverity.info:
            severityLabel = boldCyan('LOW');
            break;
        }

        buffer.writeln('$severityLabel  ${bold(issue.title)}');
        if (issue.filePath != null && issue.filePath!.isNotEmpty) {
          final lineInfo = issue.line != null ? ':${issue.line}' : '';
          buffer.writeln('      ${cyan('${issue.filePath}$lineInfo')}');
        }
        buffer.writeln();

        final descLines = issue.description.split('\n');
        for (final l in descLines) {
          buffer.writeln('      $l');
        }
        buffer.writeln();

        buffer.writeln('      ${dim('Rule: ${issue.id}')}');
        if (issue.confidence != null) {
          final pct = (issue.confidence! * 100).round();
          buffer.writeln('      ${dim('Confidence: $pct%')}');
        }

        if (issue.suggestions.isNotEmpty) {
          buffer.writeln(
            '      ${dim('Action: ${issue.suggestions.first.action}')}',
          );
        }
        buffer.writeln();
      }
    } else {
      buffer.writeln(bold('Issues'));
      buffer.writeln(dim('────────────────────────────────────────────'));
      buffer.writeln('  ${green('✓ No diagnostic issues detected.')}');
      buffer.writeln();
    }

    // Warnings
    if (report.warnings.isNotEmpty) {
      buffer.writeln(bold('Warnings'));
      buffer.writeln(dim('────────────────────────────────────────────'));
      for (final w in report.warnings) {
        buffer.writeln('  ${yellow('!')} $w');
      }
      buffer.writeln();
    }

    // Skipped Checks
    if (report.skippedAnalyses.isNotEmpty) {
      buffer.writeln(
        dim('Skipped checks: ${report.skippedAnalyses.join(', ')}'),
      );
    }

    // Unavailable
    if (report.unavailableAnalyses.isNotEmpty) {
      buffer.writeln(
        dim('Unavailable: ${report.unavailableAnalyses.join('; ')}'),
      );
    }

    // Limitations
    if (report.limitations.isNotEmpty) {
      buffer.writeln(dim('Limitations: ${report.limitations.join('; ')}'));
    }

    // Next steps
    buffer.writeln();
    buffer.writeln(bold('Next steps'));
    buffer.writeln(dim('────────────────────────────────────────────'));
    if (report.issues.isEmpty) {
      buffer.writeln('Project diagnostics passed clean. Ready for build.');
    } else {
      buffer.writeln(
        'Review findings in context. Static diagnostics are heuristic.',
      );
    }

    return buffer.toString();
  }

  static String renderJson(DiagnosticReport report) {
    return const JsonEncoder.withIndent('  ').convert(report.toJson());
  }

  static String renderMarkdown(DiagnosticReport report) {
    final buffer = StringBuffer();
    buffer.writeln('# Flutter Dev Intelligence Report');
    buffer.writeln();
    buffer.writeln('| Property | Value |');
    buffer.writeln('|---|---|');
    buffer.writeln('| Project | `${report.projectName}` |');
    if (report.projectPath != null) {
      buffer.writeln('| Path | `${report.projectPath}` |');
    }
    buffer.writeln('| Tool | `${report.toolName}` `v${report.toolVersion}` |');
    buffer.writeln('| Generated | ${report.createdAt.toIso8601String()} |');
    if (report.durationMs != null) {
      buffer.writeln('| Duration | ${report.durationMs} ms |');
    }
    buffer.writeln();

    buffer.writeln('## Summary');
    buffer.writeln();
    final highCount =
        (report.severityCounts['high'] ?? 0) +
        (report.severityCounts['critical'] ?? 0);
    final mediumCount = report.severityCounts['medium'] ?? 0;
    final lowCount =
        (report.severityCounts['low'] ?? 0) +
        (report.severityCounts['info'] ?? 0);

    buffer.writeln('- **Total Issues:** ${report.issues.length}');
    buffer.writeln('  - **High:** $highCount');
    buffer.writeln('  - **Medium:** $mediumCount');
    buffer.writeln('  - **Low:** $lowCount');
    buffer.writeln('- **Warnings:** ${report.warnings.length}');
    buffer.writeln();

    buffer.writeln('## Issues');
    buffer.writeln();

    if (report.issues.isEmpty) {
      buffer.writeln('No issues found.');
      buffer.writeln();
    } else {
      for (final issue in report.issues) {
        final severityTag = issue.severity.name.toUpperCase();
        buffer.writeln('### [$severityTag] ${issue.title}');
        if (issue.filePath != null && issue.filePath!.isNotEmpty) {
          final lineStr = issue.line != null ? ':${issue.line}' : '';
          buffer.writeln('- **Location:** `${issue.filePath}$lineStr`');
        }
        buffer.writeln('- **Rule ID:** `${issue.id}`');
        if (issue.confidence != null) {
          buffer.writeln(
            '- **Confidence:** ${(issue.confidence! * 100).round()}%',
          );
        }
        buffer.writeln('- **Description:** ${issue.description}');
        if (issue.suggestions.isNotEmpty) {
          buffer.writeln('- **Suggestion:** ${issue.suggestions.first.action}');
        }
        buffer.writeln();
      }
    }

    if (report.warnings.isNotEmpty) {
      buffer.writeln('## Warnings');
      buffer.writeln();
      for (final w in report.warnings) {
        buffer.writeln('- $w');
      }
      buffer.writeln();
    }

    if (report.limitations.isNotEmpty) {
      buffer.writeln('## Limitations');
      buffer.writeln();
      for (final l in report.limitations) {
        buffer.writeln('- $l');
      }
      buffer.writeln();
    }

    if (report.skippedAnalyses.isNotEmpty) {
      buffer.writeln('## Skipped Analyses');
      buffer.writeln();
      for (final s in report.skippedAnalyses) {
        buffer.writeln('- $s');
      }
      buffer.writeln();
    }

    if (report.unavailableAnalyses.isNotEmpty) {
      buffer.writeln('## Unavailable Analyses');
      buffer.writeln();
      for (final u in report.unavailableAnalyses) {
        buffer.writeln('- $u');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
