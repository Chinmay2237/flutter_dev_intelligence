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
    bool useAscii = false,
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
    String boldBlue(String text) => style(text, '1;34');
    String boldCyan(String text) => style(text, '1;36');

    final dividerChar = useAscii ? '-' : '─';
    final divider = dividerChar * 44;
    final passSymbol = useAscii ? '[OK]' : '✓';
    final warnSymbol = useAscii ? '[!]' : '!';

    final buffer = StringBuffer();

    // Tool Header
    buffer.writeln(bold('Flutter Dev Intelligence ${report.toolVersion}'));
    buffer.writeln(dim(divider));

    // Project Metadata
    if (commandName != null && commandName.isNotEmpty) {
      buffer.writeln('${bold('Command:')}     $commandName');
    }
    buffer.writeln('${bold('Project:')}     ${report.projectName}');
    if (report.durationMs != null) {
      buffer.writeln('${bold('Duration:')}    ${report.durationMs} ms');
    }
    if (report.filesAnalyzed != null) {
      buffer.writeln('${bold('Files analyzed:')} ${report.filesAnalyzed}');
    }
    if (report.rulesExecuted != null) {
      buffer.writeln('${bold('Rules executed:')} ${report.rulesExecuted}');
    }
    buffer.writeln();

    // Summary Section
    buffer.writeln(bold('Summary'));
    buffer.writeln(dim(divider));
    final criticalCount = report.severityCounts['critical'] ?? 0;
    final highCount = report.severityCounts['high'] ?? 0;
    final mediumCount = report.severityCounts['medium'] ?? 0;
    final lowCount = report.severityCounts['low'] ?? 0;
    final infoCount = report.severityCounts['info'] ?? 0;
    final warningCount = report.warnings.length;

    buffer.writeln(
      '  Critical   ${criticalCount > 0 ? boldRed(criticalCount.toString()) : criticalCount}',
    );
    buffer.writeln(
      '  High       ${highCount > 0 ? boldRed(highCount.toString()) : highCount}',
    );
    buffer.writeln(
      '  Medium     ${mediumCount > 0 ? yellow(mediumCount.toString()) : mediumCount}',
    );
    buffer.writeln('  Low        $lowCount');
    buffer.writeln('  Info       $infoCount');
    if (warningCount > 0) {
      buffer.writeln('  Warnings   ${yellow(warningCount.toString())}');
    }
    buffer.writeln();

    // Issues Section
    if (report.issues.isNotEmpty) {
      buffer.writeln(bold('Issues'));
      buffer.writeln(dim(divider));
      buffer.writeln();

      for (final issue in report.issues) {
        String severityLabel;
        switch (issue.severity) {
          case DiagnosticSeverity.critical:
            severityLabel = boldRed('[CRITICAL]');
            break;
          case DiagnosticSeverity.high:
            severityLabel = boldRed('[HIGH]');
            break;
          case DiagnosticSeverity.medium:
            severityLabel = boldYellow('[MEDIUM]');
            break;
          case DiagnosticSeverity.low:
            severityLabel = boldBlue('[LOW]');
            break;
          case DiagnosticSeverity.info:
            severityLabel = boldCyan('[INFO]');
            break;
        }

        buffer.writeln('$severityLabel ${bold(issue.title)}');
        if (issue.filePath != null && issue.filePath!.isNotEmpty) {
          final lineInfo = issue.line != null ? ':${issue.line}' : '';
          buffer.writeln(
            '      Location: ${cyan('${issue.filePath}$lineInfo')}',
          );
        }
        buffer.writeln('      Rule ID:  ${dim(issue.id)}');
        if (issue.confidence != null) {
          final pct = (issue.confidence! * 100).round();
          buffer.writeln('      Confidence: ${dim('$pct%')}');
        }

        final descLines = issue.description.split('\n');
        buffer.writeln('      Details:  ${descLines.first}');
        for (var i = 1; i < descLines.length; i += 1) {
          buffer.writeln('                ${descLines[i]}');
        }

        if (issue.evidence.isNotEmpty) {
          for (final ev in issue.evidence) {
            buffer.writeln('      Evidence: ${ev.label} = ${ev.value}');
          }
        }

        if (issue.suggestions.isNotEmpty) {
          buffer.writeln('      Action:   ${issue.suggestions.first.action}');
        }

        buffer.writeln(
          '      Doc:      https://pub.dev/packages/flutter_dev_intelligence#${issue.id}',
        );
        buffer.writeln();
      }
    } else {
      buffer.writeln(bold('Issues'));
      buffer.writeln(dim(divider));
      buffer.writeln(
        '  ${green('$passSymbol No diagnostic issues detected.')}',
      );
      buffer.writeln();
    }

    // Warnings
    if (report.warnings.isNotEmpty) {
      buffer.writeln(bold('Warnings'));
      buffer.writeln(dim(divider));
      for (final w in report.warnings) {
        buffer.writeln('  ${yellow(warnSymbol)} $w');
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

    // Analysis Status Footer
    buffer.writeln();
    buffer.writeln(bold('Analysis status'));
    buffer.writeln(dim(divider));
    if (report.issues.isEmpty) {
      buffer.writeln(
        '${green('$passSymbol PASSED')} — 0 actionable issues found.',
      );
    } else {
      final highOrCritical =
          (report.severityCounts['high'] ?? 0) +
          (report.severityCounts['critical'] ?? 0);
      final statusText = highOrCritical > 0
          ? 'ACTIONABLE FINDINGS DETECTED'
          : 'WARNINGS OBSERVED';
      buffer.writeln(
        '${boldYellow(statusText)} — ${report.issues.length} total issue(s) reported.',
      );
    }

    return buffer.toString();
  }

  static String renderJson(DiagnosticReport report) {
    final rawJson = const JsonEncoder.withIndent('  ').convert(report.toJson());
    return stripAnsi(rawJson);
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
    if (report.filesAnalyzed != null) {
      buffer.writeln('| Files Analyzed | ${report.filesAnalyzed} |');
    }
    if (report.rulesExecuted != null) {
      buffer.writeln('| Rules Executed | ${report.rulesExecuted} |');
    }
    buffer.writeln();

    buffer.writeln('## Summary');
    buffer.writeln();
    final criticalCount = report.severityCounts['critical'] ?? 0;
    final highCount = report.severityCounts['high'] ?? 0;
    final mediumCount = report.severityCounts['medium'] ?? 0;
    final lowCount = report.severityCounts['low'] ?? 0;
    final infoCount = report.severityCounts['info'] ?? 0;

    buffer.writeln('- **Total Issues:** ${report.issues.length}');
    buffer.writeln('  - **Critical:** $criticalCount');
    buffer.writeln('  - **High:** $highCount');
    buffer.writeln('  - **Medium:** $mediumCount');
    buffer.writeln('  - **Low:** $lowCount');
    buffer.writeln('  - **Info:** $infoCount');
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
        buffer.writeln(
          '- **Documentation:** https://pub.dev/packages/flutter_dev_intelligence#${issue.id}',
        );
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

    return stripAnsi(buffer.toString());
  }
}
