import 'dart:io';

import '../core/models.dart';
import '../core/project_config.dart';
import 'build_doctor_engine.dart';
import 'reporting.dart';

/// CLI handler for Build Doctor diagnostics.
class BuildDoctorCli {
  const BuildDoctorCli();

  static Future<int> run({
    String? projectPath,
    String? logPath,
    String outputFormat = 'terminal',
    String? outputPath,
    bool quiet = false,
    bool verbose = false,
    bool redactSecrets = true,
    ColorMode colorMode = ColorMode.auto,
    bool useAscii = false,
  }) async {
    final effectiveProjectPath = projectPath ?? Directory.current.path;

    String logContent;
    String sourceLabel;

    if (logPath != null) {
      final file = File(logPath);
      if (!await file.exists()) {
        stderr.writeln('Error: Build log file not found: $logPath');
        return 2;
      }
      logContent = await file.readAsString();
      sourceLabel = logPath;
    } else {
      stderr.writeln('Error: Build Doctor requires a log file path.');
      return 2;
    }

    try {
      final configResult = await ProjectConfig.findAndLoad(
        effectiveProjectPath,
      );

      final report = await BuildDoctorEngine.analyze(
        options: BuildDoctorEngineOptions(
          logPath: sourceLabel,
          logContent: logContent,
          projectPath: effectiveProjectPath,
          redactSecrets: redactSecrets,
          config: configResult.config,
        ),
      );

      final rendered = switch (outputFormat.toLowerCase()) {
        'json' => JsonReporter.render(report),
        'markdown' => MarkdownReporter.render(report),
        _ => TerminalReporter.render(
          report,
          colorMode: colorMode,
          useAscii: useAscii,
        ),
      };

      if (outputPath != null) {
        try {
          await File(outputPath).parent.create(recursive: true);
          final fileContent =
              (outputFormat == 'terminal' && colorMode != ColorMode.always)
              ? TerminalReporter.stripAnsi(rendered)
              : rendered;
          await File(outputPath).writeAsString('$fileContent\n');
        } catch (e) {
          stderr.writeln(
            'Error: Failed to write output file: $outputPath ($e)',
          );
          return 3;
        }
      }

      if (!quiet) {
        stdout.write(rendered);
        if (!rendered.endsWith('\n')) stdout.writeln();
      }

      final hasErrorOrCritical = report.findings.any(
        (finding) =>
            finding.severity == DiagnosticSeverity.error ||
            finding.severity == DiagnosticSeverity.critical,
      );

      return hasErrorOrCritical ? 1 : 0;
    } catch (error, stack) {
      stderr.writeln('Error: Build Doctor execution failed: $error');
      if (verbose) stderr.writeln(stack);
      return 3;
    }
  }
}
