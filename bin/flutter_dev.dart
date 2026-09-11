#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

Future<void> main(List<String> arguments) async {
  final command = arguments.isEmpty ? 'help' : arguments.first;

  switch (command) {
    case 'help':
    case '--help':
    case '-h':
      _printHelp();
      exitCode = 0;
      return;

    case '--version':
    case '-v':
      stdout.writeln('flutter_dev_intelligence 0.1.0-dev.1');
      exitCode = 0;
      return;

    case 'doctor':
      exitCode = await _runDoctor(arguments.skip(1).toList());
      return;

    case 'build-doctor':
    case 'build':
      final args = command == 'build'
          ? (arguments.length > 1 && arguments[1] == 'doctor'
                ? arguments.skip(2).toList()
                : arguments.skip(1).toList())
          : arguments.skip(1).toList();
      exitCode = await _runBuildDoctor(args);
      return;

    case 'ui-doctor':
    case 'ui':
      exitCode = await _runUiDoctor(arguments.skip(1).toList());
      return;

    case 'performance':
    case 'perf':
      exitCode = await _runPerformance(arguments.skip(1).toList());
      return;

    default:
      if (!command.startsWith('-')) {
        // Fallback for single path positional argument: `flutter-dev ./path`
        exitCode = await _runDoctor(arguments);
      } else {
        _printHelp();
        exitCode = 2;
      }
      return;
  }
}

Future<int> _runDoctor(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  if (!await Directory(options.projectPath).exists()) {
    stderr.writeln('Project directory not found: ${options.projectPath}');
    return 2;
  }

  try {
    final report = await DoctorRunner.run(
      DoctorOptions(projectPath: options.projectPath, logPath: options.logPath),
    );
    return await _renderAndOutput(report, options);
  } on FileSystemException catch (error) {
    stderr.writeln('Unable to write report: ${error.message}');
    return 3;
  } catch (error) {
    stderr.writeln('Diagnostic execution failed: $error');
    return 3;
  }
}

Future<int> _runBuildDoctor(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  if (options.logPath == null) {
    stderr.writeln('Build Doctor requires --log <path>.');
    return 2;
  }

  final logFile = File(options.logPath!);
  if (!await logFile.exists()) {
    stderr.writeln('Build log file not found: ${options.logPath}');
    return 2;
  }

  try {
    final logContent = await logFile.readAsString();
    final issues = BuildLogParser.parse(logContent);

    final report = DiagnosticReport(
      id: 'build_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: 'build-log-analysis',
      projectPath: options.projectPath,
      issues: issues,
      analyzedSources: const ['build log'],
    );

    return await _renderAndOutput(report, options);
  } catch (error) {
    stderr.writeln('Build Doctor execution failed: $error');
    return 3;
  }
}

Future<int> _runUiDoctor(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  final libDir = Directory(
    '${options.projectPath}${Platform.pathSeparator}lib',
  );
  if (!await libDir.exists()) {
    stderr.writeln(
      'Lib directory not found for static UI analysis: ${libDir.path}',
    );
    return 2;
  }

  try {
    final results = await UiAstAnalyzer.analyzeDirectory(libDir.path);
    final issues = results.expand((r) => r.issues).toList();

    final report = DiagnosticReport(
      id: 'ui_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: 'static-ui-analysis',
      projectPath: options.projectPath,
      issues: issues,
      analyzedSources: results.map((r) => r.filePath).toList(),
      limitations: const [
        'Static UI analysis is based on Dart AST heuristics. Runtime layout verification is recommended.',
      ],
    );

    return await _renderAndOutput(report, options);
  } catch (error) {
    stderr.writeln('UI Doctor execution failed: $error');
    return 3;
  }
}

Future<int> _runPerformance(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  String? inputPath = options.inputPath;
  if (inputPath == null && options.logPath != null) {
    inputPath = options.logPath;
  }

  if (inputPath == null) {
    stderr.writeln('Performance doctor requires --input <trace.json>.');
    return 2;
  }

  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('Performance trace file not found: $inputPath');
    return 2;
  }

  try {
    final text = await inputFile.readAsString();
    final json = jsonDecode(text) as Map<String, dynamic>;
    final summary = FrameTimingSummary.fromJson(json);
    final recommendations = summary.generateRecommendations();

    final report = DiagnosticReport(
      id: 'perf_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: 'performance-analysis',
      issues: recommendations,
      metrics: summary.toJson(),
      analyzedSources: [inputPath],
    );

    return await _renderAndOutput(report, options);
  } catch (error) {
    stderr.writeln('Performance analysis execution failed: $error');
    return 3;
  }
}

class _CliOptions {
  _CliOptions({
    required this.projectPath,
    this.logPath,
    this.inputPath,
    this.format = 'terminal',
    this.outputPath,
    this.quiet = false,
    this.verbose = false,
    this.noAi = false,
    this.errorExitCode,
  });

  final String projectPath;
  final String? logPath;
  final String? inputPath;
  final String format;
  final String? outputPath;
  final bool quiet;
  final bool verbose;
  final bool noAi;
  final int? errorExitCode;
}

_CliOptions _parseCommonArgs(List<String> arguments) {
  var projectPath = Directory.current.path;
  String? logPath;
  String? inputPath;
  var format = 'terminal';
  String? outputPath;
  var quiet = false;
  var verbose = false;
  var noAi = false;

  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    String? value;
    if (argument == '--project' ||
        argument == '--log' ||
        argument == '--input' ||
        argument == '--format' ||
        argument == '--output') {
      if (index + 1 >= arguments.length) {
        stderr.writeln('Missing value for $argument.');
        return _CliOptions(projectPath: projectPath, errorExitCode: 2);
      }
      value = arguments[++index];
    }

    switch (argument) {
      case '--project':
        projectPath = value!;
        break;
      case '--log':
        logPath = value!;
        break;
      case '--input':
        inputPath = value!;
        break;
      case '--format':
        format = value!.toLowerCase();
        break;
      case '--output':
        outputPath = value!;
        break;
      case '--verbose':
        verbose = true;
        break;
      case '--quiet':
        quiet = true;
        break;
      case '--no-ai':
        noAi = true;
        break;
      default:
        if (!argument.startsWith('-') && arguments.length == 1) {
          projectPath = argument;
        } else {
          stderr.writeln('Unknown option: $argument');
          return _CliOptions(projectPath: projectPath, errorExitCode: 2);
        }
    }
  }

  if (!const {'terminal', 'json', 'markdown'}.contains(format)) {
    stderr.writeln('Unsupported output format: $format');
    return _CliOptions(projectPath: projectPath, errorExitCode: 2);
  }

  return _CliOptions(
    projectPath: projectPath,
    logPath: logPath,
    inputPath: inputPath,
    format: format,
    outputPath: outputPath,
    quiet: quiet,
    verbose: verbose,
    noAi: noAi,
  );
}

Future<int> _renderAndOutput(
  DiagnosticReport report,
  _CliOptions options,
) async {
  final rendered = switch (options.format) {
    'json' => DiagnosticReportRenderer.renderJson(report),
    'markdown' => DiagnosticReportRenderer.renderMarkdown(report),
    _ => DiagnosticReportRenderer.renderTerminal(report),
  };

  if (options.outputPath != null) {
    await File(options.outputPath!).parent.create(recursive: true);
    await File(options.outputPath!).writeAsString('$rendered\n');
  } else if (!options.quiet) {
    stdout.write(rendered);
    if (!rendered.endsWith('\n')) {
      stdout.writeln();
    }
  }

  if (options.verbose && !options.quiet && options.format == 'terminal') {
    stdout.writeln('Analyzed sources: ${report.analyzedSources.join(', ')}');
  }

  return report.issues.isEmpty ? 0 : 1;
}

void _printHelp() {
  stdout.writeln('Flutter Dev Intelligence CLI');
  stdout.writeln('');
  stdout.writeln('Usage: flutter-dev <command> [options]');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln(
    '  doctor          Run complete project diagnostics (scans pubspec, lockfile, UI AST, log)',
  );
  stdout.writeln(
    '  build-doctor    Run build log diagnostic rules (--log <path> required)',
  );
  stdout.writeln(
    '  ui-doctor       Run static Dart AST UI layout heuristics (--project <path>)',
  );
  stdout.writeln(
    '  performance     Analyze frame timing trace metrics (--input <trace.json>)',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --project <path>   Project root directory (default: current directory)',
  );
  stdout.writeln('  --log <path>       Build log file path');
  stdout.writeln('  --input <path>     Trace / metrics JSON file path');
  stdout.writeln(
    '  --format <name>    Output format: terminal, json, or markdown (default: terminal)',
  );
  stdout.writeln('  --output <path>    Write output report to file');
  stdout.writeln('  --verbose          Print additional diagnostic details');
  stdout.writeln('  --quiet            Suppress report stdout output');
  stdout.writeln(
    '  --no-ai            Disable optional AI provider enrichment',
  );
  stdout.writeln('  --help, -h         Print this help message');
  stdout.writeln('  --version, -v      Print package version');
}
