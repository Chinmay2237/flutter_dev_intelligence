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
      stdout.writeln('flutter_dev_intelligence $kPackageVersion');
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

Future<String> _resolveProjectName(String projectPath) async {
  final pubspec = await PubspecAnalyzer.analyze(projectPath);
  if (pubspec.packageName.isNotEmpty) {
    return pubspec.packageName;
  }
  final dir = Directory(projectPath);
  final basename = dir.absolute.path
      .replaceAll(RegExp(r'[/\\]+$'), '')
      .split(Platform.pathSeparator)
      .last;
  return (basename.isEmpty || basename == '.') ? 'flutter-project' : basename;
}

Future<int> _runDoctor(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  if (options.useStdin) {
    stderr.writeln('Error: The doctor command does not support --stdin.');
    stderr.writeln('Use --project <directory> instead.');
    return 2;
  }

  if (!await Directory(options.projectPath).exists()) {
    stderr.writeln(
      'Error: Project directory not found: ${options.projectPath}',
    );
    return 2;
  }

  try {
    final report = await DoctorRunner.run(
      DoctorOptions(projectPath: options.projectPath, logPath: options.logPath),
    );
    return await _renderAndOutput(report, options, commandName: 'doctor');
  } on FileSystemException catch (error) {
    stderr.writeln('Error: Unable to write report: ${error.message}');
    return 3;
  } catch (error, stack) {
    stderr.writeln('Error: Diagnostic execution failed: $error');
    if (options.verbose) stderr.writeln(stack);
    return 3;
  }
}

Future<int> _runBuildDoctor(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  if (options.useStdin && options.logPath != null) {
    stderr.writeln('Error: Cannot combine --stdin and --log.');
    return 2;
  }

  String logContent;
  String sourceLabel;

  if (options.useStdin) {
    logContent = await _readStdin();
    if (logContent.trim().isEmpty) {
      stderr.writeln('Error: Standard input (stdin) was empty.');
      return 2;
    }
    sourceLabel = 'stdin';
  } else if (options.logPath != null) {
    final logFile = File(options.logPath!);
    if (!await logFile.exists()) {
      stderr.writeln('Error: Build log file not found: ${options.logPath}');
      return 2;
    }
    logContent = await logFile.readAsString();
    sourceLabel = options.logPath!;
  } else {
    stderr.writeln('Error: Build Doctor requires --log <path> or --stdin.');
    stderr.writeln();
    stderr.writeln('Usage:');
    stderr.writeln('  flutter-dev build-doctor --log <path>');
    stderr.writeln('  flutter-dev build-doctor --stdin');
    return 2;
  }

  try {
    final issues = BuildLogParser.parse(logContent);
    final projectName = await _resolveProjectName(options.projectPath);

    final report = DiagnosticReport(
      id: 'build_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: projectName,
      projectPath: options.projectPath,
      issues: issues,
      analyzedSources: [sourceLabel],
      limitations: const [
        'Build analysis evaluates supplied logs and does not execute the build itself.',
      ],
    );

    return await _renderAndOutput(report, options, commandName: 'build-doctor');
  } catch (error, stack) {
    stderr.writeln('Error: Build Doctor execution failed: $error');
    if (options.verbose) stderr.writeln(stack);
    return 3;
  }
}

Future<int> _runUiDoctor(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  if (options.useStdin) {
    stderr.writeln('Error: The ui-doctor command does not support --stdin.');
    stderr.writeln('Use --project <directory> instead.');
    return 2;
  }

  final libDir = Directory(
    '${options.projectPath}${Platform.pathSeparator}lib',
  );
  if (!await libDir.exists()) {
    stderr.writeln(
      'Error: Lib directory not found for static UI analysis: ${libDir.path}',
    );
    return 2;
  }

  try {
    final results = await UiAstAnalyzer.analyzeDirectory(libDir.path);
    final issues = results.expand((r) => r.issues).toList();
    final projectName = await _resolveProjectName(options.projectPath);

    final report = DiagnosticReport(
      id: 'ui_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: projectName,
      projectPath: options.projectPath,
      issues: issues,
      analyzedSources: results.map((r) => r.filePath).toList(),
      limitations: const [
        'Static UI findings are based on Dart AST source analysis. Runtime layout behavior is not executed.',
      ],
    );

    return await _renderAndOutput(report, options, commandName: 'ui-doctor');
  } catch (error, stack) {
    stderr.writeln('Error: UI Doctor execution failed: $error');
    if (options.verbose) stderr.writeln(stack);
    return 3;
  }
}

Future<int> _runPerformance(List<String> arguments) async {
  final options = _parseCommonArgs(arguments);
  if (options.errorExitCode != null) return options.errorExitCode!;

  final inputPath = options.inputPath ?? options.logPath;
  if (options.useStdin && inputPath != null) {
    stderr.writeln('Error: Cannot combine --stdin and --input.');
    return 2;
  }

  String jsonText;
  String sourceLabel;

  if (options.useStdin) {
    jsonText = await _readStdin();
    if (jsonText.trim().isEmpty) {
      stderr.writeln('Error: Standard input (stdin) was empty.');
      return 2;
    }
    sourceLabel = 'stdin';
  } else if (inputPath != null) {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      stderr.writeln('Error: Performance trace file not found: $inputPath');
      return 2;
    }
    jsonText = await inputFile.readAsString();
    sourceLabel = inputPath;
  } else {
    stderr.writeln(
      'Error: Performance doctor requires --input <trace.json> or --stdin.',
    );
    return 2;
  }

  try {
    final dynamic parsedJson = jsonDecode(jsonText);
    if (parsedJson is! Map<String, dynamic>) {
      stderr.writeln('Error: Performance trace input must be a JSON object.');
      return 2;
    }
    final summary = FrameTimingSummary.fromJson(parsedJson);
    final recommendations = summary.generateRecommendations();
    final projectName = await _resolveProjectName(options.projectPath);

    final report = DiagnosticReport(
      id: 'perf_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: projectName,
      projectPath: options.projectPath,
      issues: recommendations,
      metrics: summary.toJson(),
      analyzedSources: [sourceLabel],
      limitations: summary.frameCount == 0
          ? const [
              'Performance analysis requires valid trace data. No frame timing events were recognized in input.',
            ]
          : const [
              'Performance analysis requires a supported frame trace. This command does not automatically profile a running application.',
            ],
    );

    return await _renderAndOutput(report, options, commandName: 'performance');
  } on FormatException catch (error) {
    stderr.writeln(
      'Error: Performance trace input is invalid JSON: ${error.message}',
    );
    return 2;
  } catch (error, stack) {
    stderr.writeln('Error: Performance analysis execution failed: $error');
    if (options.verbose) stderr.writeln(stack);
    return 3;
  }
}

Future<String> _readStdin() async {
  return await systemEncoding.decodeStream(stdin);
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
    this.useStdin = false,
    this.colorMode = ColorMode.auto,
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
  final bool useStdin;
  final ColorMode colorMode;
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
  var useStdin = false;
  var colorMode = ColorMode.auto;

  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    String? value;
    if (argument == '--project' ||
        argument == '--log' ||
        argument == '--input' ||
        argument == '--format' ||
        argument == '--output' ||
        argument == '--color') {
      if (index + 1 >= arguments.length) {
        stderr.writeln('Error: Missing value for $argument.');
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
      case '--color':
        switch (value!.toLowerCase()) {
          case 'always':
            colorMode = ColorMode.always;
            break;
          case 'never':
            colorMode = ColorMode.never;
            break;
          case 'auto':
            colorMode = ColorMode.auto;
            break;
          default:
            stderr.writeln(
              'Error: Invalid --color mode: $value. Choose auto, always, or never.',
            );
            return _CliOptions(projectPath: projectPath, errorExitCode: 2);
        }
        break;
      case '--no-color':
        colorMode = ColorMode.never;
        break;
      case '--stdin':
        useStdin = true;
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
          stderr.writeln('Error: Unknown option: $argument');
          return _CliOptions(projectPath: projectPath, errorExitCode: 2);
        }
    }
  }

  if (!const {'terminal', 'json', 'markdown'}.contains(format)) {
    stderr.writeln(
      'Error: Unsupported output format: $format. Choose terminal, json, or markdown.',
    );
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
    useStdin: useStdin,
    colorMode: colorMode,
  );
}

Future<int> _renderAndOutput(
  DiagnosticReport report,
  _CliOptions options, {
  String? commandName,
}) async {
  final rendered = switch (options.format) {
    'json' => DiagnosticReportRenderer.renderJson(report),
    'markdown' => DiagnosticReportRenderer.renderMarkdown(report),
    _ => DiagnosticReportRenderer.renderTerminal(
      report,
      colorMode: options.colorMode,
      commandName: commandName,
    ),
  };

  if (options.outputPath != null) {
    await File(options.outputPath!).parent.create(recursive: true);
    // Strip ANSI codes if saving terminal report to file unless color explicitly forced
    final fileContent =
        (options.format == 'terminal' && options.colorMode != ColorMode.always)
        ? DiagnosticReportRenderer.stripAnsi(rendered)
        : rendered;
    await File(options.outputPath!).writeAsString('$fileContent\n');
  }

  if (!options.quiet) {
    stdout.write(rendered);
    if (!rendered.endsWith('\n')) stdout.writeln();
  }

  if (options.verbose && !options.quiet && options.format == 'terminal') {
    stdout.writeln('Analyzed sources: ${report.analyzedSources.join(', ')}');
  }

  final hasActionableIssues = report.issues.any(
    (issue) =>
        issue.severity == DiagnosticSeverity.high ||
        issue.severity == DiagnosticSeverity.critical ||
        issue.severity == DiagnosticSeverity.medium,
  );

  return hasActionableIssues ? 1 : 0;
}

void _printHelp() {
  stdout.writeln('Flutter Dev Intelligence');
  stdout.writeln('');
  stdout.writeln('Inspect Flutter projects, build logs, static UI patterns,');
  stdout.writeln('and performance traces with structured diagnostics.');
  stdout.writeln('');
  stdout.writeln('Usage: flutter-dev <command> [options]');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln(
    '  doctor          Run project-wide diagnostics (pubspec, lockfile, static UI, logs)',
  );
  stdout.writeln(
    '  build-doctor    Analyze Flutter/Dart build logs (--log <path> or --stdin)',
  );
  stdout.writeln(
    '  ui-doctor       Analyze static Flutter Dart AST UI layout heuristics (--project <path>)',
  );
  stdout.writeln(
    '  performance     Analyze performance frame timing trace data (--input <trace.json> or --stdin)',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --project <path>   Project root directory (default: current directory)',
  );
  stdout.writeln('  --log <path>       Build log file path');
  stdout.writeln('  --input <path>     Trace / metrics JSON file path');
  stdout.writeln(
    '  --stdin            Read log or trace input from standard input pipe',
  );
  stdout.writeln(
    '  --format <format>  Output format: terminal, json, or markdown (default: terminal)',
  );
  stdout.writeln(
    '  --output <path>    Write output report to specified file path',
  );
  stdout.writeln(
    '  --color <mode>     Terminal color mode: auto, always, or never (default: auto)',
  );
  stdout.writeln(
    '  --no-color         Disable terminal colors (same as --color never)',
  );
  stdout.writeln(
    '  --no-ai            Disable optional AI provider enrichment',
  );
  stdout.writeln(
    '  --verbose          Print detailed execution diagnostics and stack traces',
  );
  stdout.writeln('  --quiet            Suppress stdout output');
  stdout.writeln('  --help, -h         Show this help message');
  stdout.writeln('  --version, -v      Show package version');
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln(
    '  dart run flutter_dev_intelligence:flutter_dev doctor --project .',
  );
  stdout.writeln(
    '  flutter analyze 2>&1 | dart run flutter_dev_intelligence:flutter_dev build-doctor --stdin',
  );
  stdout.writeln(
    '  cat trace.json | dart run flutter_dev_intelligence:flutter_dev performance --stdin',
  );
  stdout.writeln(
    '  dart run flutter_dev_intelligence:flutter_dev ui-doctor --format json --output report.json',
  );
}
