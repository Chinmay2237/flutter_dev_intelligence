#!/usr/bin/env dart

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
    case 'doc':
      exitCode = await _runDoctor(arguments.skip(1).toList());
      return;

    case 'build-doctor':
    case 'build':
    case 'build_doctor':
      final args = (command == 'build' || command == 'build_doctor')
          ? (arguments.length > 1 && arguments[1] == 'doctor'
                ? arguments.skip(2).toList()
                : arguments.skip(1).toList())
          : arguments.skip(1).toList();
      exitCode = await _runBuildDoctor(args);
      return;

    case 'ui-doctor':
    case 'ui':
    case 'ui_doctor':
      final args = (command == 'ui' || command == 'ui_doctor')
          ? (arguments.length > 1 && arguments[1] == 'doctor'
                ? arguments.skip(2).toList()
                : arguments.skip(1).toList())
          : arguments.skip(1).toList();
      exitCode = await _runUiDoctor(args);
      return;

    case 'performance':
    case 'perf':
    case 'perf-investigator':
    case 'perf_investigator':
    case 'performance_investigator':
      final args =
          (command == 'perf' ||
              command == 'perf-investigator' ||
              command == 'perf_investigator' ||
              command == 'performance_investigator')
          ? (arguments.length > 1 && arguments[1] == 'doctor'
                ? arguments.skip(2).toList()
                : arguments.skip(1).toList())
          : arguments.skip(1).toList();
      exitCode = await _runPerformance(args);
      return;

    default:
      if (!command.startsWith('-') && Directory(command).existsSync()) {
        exitCode = await _runDoctor(arguments);
      } else {
        stderr.writeln("Error: Unknown command '$command'.");
        stderr.writeln(
          "Run 'flutter_dev_intelligence --help' for available commands.",
        );
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

  final configValidation = await ProjectConfig.findAndLoad(
    options.projectPath,
    customConfigPath: options.configPath,
  );
  if (!configValidation.isValid) {
    stderr.writeln('Error: Invalid project configuration:');
    for (final err in configValidation.errors) {
      stderr.writeln('  - $err');
    }
    return 2;
  }

  try {
    final report = await DoctorRunner.run(
      DoctorOptions(
        projectPath: options.projectPath,
        logPath: options.logPath,
        configPath: options.configPath,
      ),
      config: configValidation.config,
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

  final configValidation = await ProjectConfig.findAndLoad(
    options.projectPath,
    customConfigPath: options.configPath,
  );
  if (!configValidation.isValid) {
    stderr.writeln('Error: Invalid project configuration:');
    for (final err in configValidation.errors) {
      stderr.writeln('  - $err');
    }
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
    stderr.writeln('  flutter_dev_intelligence build-doctor --log <path>');
    stderr.writeln('  flutter_dev_intelligence build-doctor --stdin');
    return 2;
  }

  try {
    final rawIssues = BuildLogParser.parse(
      logContent,
      maxLogSizeBytes: configValidation.config.maxLogSizeBytes,
    );
    final issues = DiagnosticFilter.filterIssues(
      rawIssues,
      configValidation.config,
    );
    final projectName = await _resolveProjectName(options.projectPath);

    final report = DiagnosticReport(
      id: 'build_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: projectName,
      projectPath: options.projectPath,
      commandName: 'build-doctor',
      analyzerType: 'BuildLogParser',
      rulesExecuted: 41,
      issues: issues,
      analyzedSources: [sourceLabel],
      skippedAnalyses: const [
        'project health',
        'static UI analysis',
        'performance trace analysis',
      ],
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
    stderr.writeln('Use --project <directory> or --file <path> instead.');
    return 2;
  }

  final configValidation = await ProjectConfig.findAndLoad(
    options.projectPath,
    customConfigPath: options.configPath,
  );
  if (!configValidation.isValid) {
    stderr.writeln('Error: Invalid project configuration:');
    for (final err in configValidation.errors) {
      stderr.writeln('  - $err');
    }
    return 2;
  }

  try {
    List<UiAstAnalysisResult> results;
    if (options.filePath != null) {
      final file = File(options.filePath!);
      if (!await file.exists()) {
        stderr.writeln('Error: Source file not found: ${options.filePath}');
        return 2;
      }
      final res = await UiAstAnalyzer.analyzeFile(
        options.filePath!,
        config: configValidation.config,
      );
      results = [res];
    } else {
      final libDir = Directory(
        '${options.projectPath}${Platform.pathSeparator}lib',
      );
      if (!await libDir.exists()) {
        stderr.writeln(
          'Error: Lib directory not found for static UI analysis: ${libDir.path}',
        );
        return 2;
      }
      results = await UiAstAnalyzer.analyzeDirectory(
        libDir.path,
        config: configValidation.config,
      );
    }

    final rawIssues = results.expand((r) => r.issues).toList();
    final issues = DiagnosticFilter.filterIssues(
      rawIssues,
      configValidation.config,
    );
    final projectName = await _resolveProjectName(options.projectPath);

    final report = DiagnosticReport(
      id: 'ui_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: projectName,
      projectPath: options.projectPath,
      commandName: 'ui-doctor',
      analyzerType: 'UiAstAnalyzer',
      rulesExecuted: 17,
      issues: issues,
      analyzedSources: results.map((r) => r.filePath).toList(),
      filesAnalyzed: results.length,
      skippedAnalyses: const [
        'project health',
        'build log analysis',
        'performance trace analysis',
      ],
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

  if (options.useStdin && options.inputPath != null) {
    stderr.writeln('Error: Cannot combine --stdin and --input/--trace.');
    return 2;
  }

  final configValidation = await ProjectConfig.findAndLoad(
    options.projectPath,
    customConfigPath: options.configPath,
  );
  if (!configValidation.isValid) {
    stderr.writeln('Error: Invalid project configuration:');
    for (final err in configValidation.errors) {
      stderr.writeln('  - $err');
    }
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
  } else if (options.inputPath != null) {
    final inputFile = File(options.inputPath!);
    if (!await inputFile.exists()) {
      stderr.writeln(
        'Error: Performance trace file not found: ${options.inputPath}',
      );
      return 2;
    }
    jsonText = await inputFile.readAsString();
    sourceLabel = options.inputPath!;
  } else {
    stderr.writeln(
      'Error: Performance doctor requires --input <trace.json>, --trace <trace.json>, or --stdin.',
    );
    stderr.writeln('No performance trace data was supplied.');
    stderr.writeln();
    stderr.writeln('Usage:');
    stderr.writeln(
      '  flutter_dev_intelligence performance --input <trace.json>',
    );
    stderr.writeln(
      '  cat devtools_trace.json | flutter_dev_intelligence performance --stdin',
    );
    return 2;
  }

  try {
    final parseResult = PerformanceInputParser.parse(
      jsonText,
      refreshRateHz: configValidation.config.refreshRateHz,
    );

    if (!parseResult.isValid || parseResult.summary == null) {
      stderr.writeln('Error: Performance trace input could not be analyzed:');
      for (final limitation in parseResult.limitations) {
        stderr.writeln('  - $limitation');
      }
      return 2;
    }

    final summary = parseResult.summary!;
    final rawIssues = summary.generateRecommendations();
    final issues = DiagnosticFilter.filterIssues(
      rawIssues,
      configValidation.config,
    );
    final projectName = await _resolveProjectName(options.projectPath);

    final report = DiagnosticReport(
      id: 'perf_doctor_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: projectName,
      projectPath: options.projectPath,
      commandName: 'performance',
      analyzerType: 'PerformanceInputParser',
      rulesExecuted: 5,
      issues: issues,
      metrics: summary.toJson(),
      analyzedSources: [sourceLabel],
      skippedAnalyses: const [
        'project health',
        'static UI analysis',
        'build log analysis',
      ],
      warnings: parseResult.warnings,
      limitations: parseResult.limitations.isEmpty
          ? const [
              'Performance analysis evaluates frame duration traces. This command does not profile live running applications.',
            ]
          : parseResult.limitations,
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
    this.filePath,
    this.configPath,
    this.logPath,
    this.inputPath,
    this.format = 'terminal',
    this.outputPath,
    this.quiet = false,
    this.verbose = false,
    this.noAi = false,
    this.useStdin = false,
    this.useAscii = false,
    this.colorMode = ColorMode.auto,
    this.severityFilter,
    this.confidenceFilter,
    this.ruleFilter,
    this.categoryFilter,
    this.excludeFilter,
    this.maxIssues,
    this.errorExitCode,
  });

  final String projectPath;
  final String? filePath;
  final String? configPath;
  final String? logPath;
  final String? inputPath;
  final String format;
  final String? outputPath;
  final bool quiet;
  final bool verbose;
  final bool noAi;
  final bool useStdin;
  final bool useAscii;
  final ColorMode colorMode;
  final DiagnosticSeverity? severityFilter;
  final double? confidenceFilter;
  final String? ruleFilter;
  final String? categoryFilter;
  final String? excludeFilter;
  final int? maxIssues;
  final int? errorExitCode;
}

_CliOptions _parseCommonArgs(List<String> arguments) {
  var projectPath = Directory.current.path;
  String? filePath;
  String? configPath;
  String? logPath;
  String? inputPath;
  var format = 'terminal';
  String? outputPath;
  var quiet = false;
  var verbose = false;
  var noAi = false;
  var useStdin = false;
  var useAscii = false;
  var colorMode = ColorMode.auto;
  DiagnosticSeverity? severityFilter;
  double? confidenceFilter;
  String? ruleFilter;
  String? categoryFilter;
  String? excludeFilter;
  int? maxIssues;

  for (var index = 0; index < arguments.length; index += 1) {
    final rawArg = arguments[index];
    String flag;
    String? value;

    if (rawArg.startsWith('--') && rawArg.contains('=')) {
      final eqIndex = rawArg.indexOf('=');
      flag = rawArg.substring(0, eqIndex);
      value = rawArg.substring(eqIndex + 1);
    } else {
      flag = rawArg;
    }

    const valueFlags = {
      '--project',
      '--file',
      '--config',
      '--log',
      '--input',
      '--trace',
      '--format',
      '--output',
      '--color',
      '--severity-threshold',
      '--confidence-threshold',
      '--rule',
      '--category',
      '--exclude',
      '--max-issues',
    };

    if (valueFlags.contains(flag) && value == null) {
      if (index + 1 >= arguments.length) {
        stderr.writeln('Error: Missing value for $flag.');
        return _CliOptions(projectPath: projectPath, errorExitCode: 2);
      }
      value = arguments[++index];
    }

    switch (flag) {
      case '--help':
      case '-h':
        _printHelp();
        return _CliOptions(projectPath: projectPath, errorExitCode: 0);
      case '--version':
      case '-v':
        stdout.writeln('flutter_dev_intelligence $kPackageVersion');
        return _CliOptions(projectPath: projectPath, errorExitCode: 0);
      case '--project':
        projectPath = value!;
        break;
      case '--file':
        filePath = value!;
        break;
      case '--config':
        configPath = value!;
        break;
      case '--log':
        logPath = value!;
        break;
      case '--input':
      case '--trace':
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
      case '--ascii':
        useAscii = true;
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
      case '--severity-threshold':
        final sev = value!.toLowerCase();
        switch (sev) {
          case 'critical':
            severityFilter = DiagnosticSeverity.critical;
            break;
          case 'high':
            severityFilter = DiagnosticSeverity.high;
            break;
          case 'medium':
            severityFilter = DiagnosticSeverity.medium;
            break;
          case 'low':
            severityFilter = DiagnosticSeverity.low;
            break;
          case 'info':
            severityFilter = DiagnosticSeverity.info;
            break;
          default:
            stderr.writeln(
              'Error: Invalid --severity-threshold value: $value.',
            );
            return _CliOptions(projectPath: projectPath, errorExitCode: 2);
        }
        break;
      case '--confidence-threshold':
        final parsed = double.tryParse(value!);
        if (parsed == null || parsed < 0.0 || parsed > 1.0) {
          stderr.writeln(
            'Error: Invalid --confidence-threshold value: $value (must be 0.0 to 1.0).',
          );
          return _CliOptions(projectPath: projectPath, errorExitCode: 2);
        }
        confidenceFilter = parsed;
        break;
      case '--rule':
        ruleFilter = value!;
        break;
      case '--category':
        categoryFilter = value!;
        break;
      case '--exclude':
        excludeFilter = value!;
        break;
      case '--max-issues':
        final parsed = int.tryParse(value!);
        if (parsed == null || parsed < 1) {
          stderr.writeln(
            'Error: Invalid --max-issues value: $value (must be a positive integer).',
          );
          return _CliOptions(projectPath: projectPath, errorExitCode: 2);
        }
        maxIssues = parsed;
        break;
      default:
        if (!flag.startsWith('-') &&
            (arguments.length == 1 || projectPath == Directory.current.path)) {
          projectPath = flag;
        } else {
          stderr.writeln('Error: Unknown option: $flag');
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

  if (configPath == null &&
      Platform.environment['FLUTTER_DEV_CONFIG'] != null) {
    configPath = Platform.environment['FLUTTER_DEV_CONFIG'];
  }

  return _CliOptions(
    projectPath: projectPath,
    filePath: filePath,
    configPath: configPath,
    logPath: logPath,
    inputPath: inputPath,
    format: format,
    outputPath: outputPath,
    quiet: quiet,
    verbose: verbose,
    noAi: noAi,
    useStdin: useStdin,
    useAscii: useAscii,
    colorMode: colorMode,
    severityFilter: severityFilter,
    confidenceFilter: confidenceFilter,
    ruleFilter: ruleFilter,
    categoryFilter: categoryFilter,
    excludeFilter: excludeFilter,
    maxIssues: maxIssues,
  );
}

Future<int> _renderAndOutput(
  DiagnosticReport initialReport,
  _CliOptions options, {
  String? commandName,
}) async {
  // Apply CLI-level issue filtering
  var filteredIssues = List<DiagnosticIssue>.of(initialReport.issues);

  if (options.severityFilter != null) {
    filteredIssues = filteredIssues
        .where((i) => i.severity.index >= options.severityFilter!.index)
        .toList();
  }
  if (options.confidenceFilter != null) {
    filteredIssues = filteredIssues
        .where((i) => (i.confidence ?? 1.0) >= options.confidenceFilter!)
        .toList();
  }
  if (options.ruleFilter != null && options.ruleFilter!.isNotEmpty) {
    filteredIssues = filteredIssues
        .where(
          (i) =>
              i.id == options.ruleFilter ||
              i.id.startsWith('${options.ruleFilter}.'),
        )
        .toList();
  }
  if (options.categoryFilter != null && options.categoryFilter!.isNotEmpty) {
    filteredIssues = filteredIssues
        .where(
          (i) =>
              i.category.name.toLowerCase() ==
              options.categoryFilter!.toLowerCase(),
        )
        .toList();
  }
  if (options.excludeFilter != null && options.excludeFilter!.isNotEmpty) {
    filteredIssues = filteredIssues
        .where(
          (i) =>
              i.filePath == null ||
              !i.filePath!.contains(options.excludeFilter!),
        )
        .toList();
  }

  // Deterministic Issue Sorting: Severity desc -> filePath asc -> line asc -> id asc
  filteredIssues.sort((a, b) {
    final sevCompare = b.severity.index.compareTo(a.severity.index);
    if (sevCompare != 0) return sevCompare;
    final fileCompare = (a.filePath ?? '').compareTo(b.filePath ?? '');
    if (fileCompare != 0) return fileCompare;
    final lineCompare = (a.line ?? 0).compareTo(b.line ?? 0);
    if (lineCompare != 0) return lineCompare;
    return a.id.compareTo(b.id);
  });

  if (options.maxIssues != null && filteredIssues.length > options.maxIssues!) {
    filteredIssues = filteredIssues.take(options.maxIssues!).toList();
  }

  final report = DiagnosticReport(
    id: initialReport.id,
    createdAt: initialReport.createdAt,
    projectName: initialReport.projectName,
    projectPath: initialReport.projectPath,
    commandName: commandName ?? initialReport.commandName,
    analyzerType: initialReport.analyzerType,
    analysisStatus: initialReport.analysisStatus,
    issues: filteredIssues,
    metrics: initialReport.metrics,
    warnings: initialReport.warnings,
    toolName: initialReport.toolName,
    toolVersion: initialReport.toolVersion,
    schemaVersion: initialReport.schemaVersion,
    analyzedSources: initialReport.analyzedSources,
    limitations: initialReport.limitations,
    skippedAnalyses: initialReport.skippedAnalyses,
    unavailableAnalyses: initialReport.unavailableAnalyses,
    durationMs: initialReport.durationMs,
    filesAnalyzed: initialReport.filesAnalyzed,
    rulesExecuted: initialReport.rulesExecuted,
  );

  final rendered = switch (options.format) {
    'json' => DiagnosticReportRenderer.renderJson(report),
    'markdown' => DiagnosticReportRenderer.renderMarkdown(report),
    _ => DiagnosticReportRenderer.renderTerminal(
      report,
      colorMode: options.colorMode,
      commandName: commandName,
      useAscii: options.useAscii,
    ),
  };

  if (options.outputPath != null) {
    try {
      await File(options.outputPath!).parent.create(recursive: true);
      final fileContent =
          (options.format == 'terminal' &&
              options.colorMode != ColorMode.always)
          ? DiagnosticReportRenderer.stripAnsi(rendered)
          : rendered;
      await File(options.outputPath!).writeAsString('$fileContent\n');
    } catch (e) {
      stderr.writeln(
        'Error: Failed to write output file: ${options.outputPath} ($e)',
      );
      return 3;
    }
  }

  if (!options.quiet) {
    stdout.write(rendered);
    if (!rendered.endsWith('\n')) stdout.writeln();
  }

  if (options.verbose && !options.quiet && options.format == 'terminal') {
    stderr.writeln('Analyzed sources: ${report.analyzedSources.join(', ')}');
  }

  final hasHighOrCritical = report.issues.any(
    (issue) =>
        issue.severity == DiagnosticSeverity.high ||
        issue.severity == DiagnosticSeverity.critical,
  );

  return hasHighOrCritical ? 1 : 0;
}

void _printHelp() {
  stdout.writeln('Flutter Dev Intelligence');
  stdout.writeln('');
  stdout.writeln('Inspect Flutter projects, build logs, static UI patterns,');
  stdout.writeln('and performance traces with structured diagnostics.');
  stdout.writeln('');
  stdout.writeln(
    'Usage: flutter_dev_intelligence <command> [options] (or dart run flutter_dev_intelligence <command> [options])',
  );
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln(
    '  doctor          Inspect project structure, pubspec, lockfile, and SDK environment health (aliases: doc)',
  );
  stdout.writeln(
    '  ui-doctor       Analyze static Flutter Dart AST UI layout heuristics (--project <path> or --file <path>) (aliases: ui, ui_doctor)',
  );
  stdout.writeln(
    '  build-doctor    Analyze Flutter/Dart/Android/iOS build logs (--log <path> or --stdin) (aliases: build, build_doctor)',
  );
  stdout.writeln(
    '  performance     Analyze frame timing traces and DevTools Chrome traces (--input <trace.json>, --trace <trace.json>, or --stdin) (aliases: perf, perf-investigator, perf_investigator)',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --project <path>               Project root directory (default: current directory)',
  );
  stdout.writeln(
    '  --file <path>                  Single Dart source file to analyze (ui-doctor)',
  );
  stdout.writeln(
    '  --config <path>                Configuration file path (default: flutter_dev_intelligence.yaml)',
  );
  stdout.writeln(
    '  --log <path>                   Build log file path (build-doctor)',
  );
  stdout.writeln(
    '  --input <path>, --trace <path> Trace / metrics JSON file path (performance)',
  );
  stdout.writeln(
    '  --stdin                        Read log or trace input from standard input pipe',
  );
  stdout.writeln(
    '  --format <format>              Output format: terminal, json, or markdown (default: terminal)',
  );
  stdout.writeln(
    '  --output <path>                Write output report to specified file path',
  );
  stdout.writeln(
    '  --color <mode>                 Terminal color mode: auto, always, or never (default: auto)',
  );
  stdout.writeln(
    '  --no-color                     Disable terminal colors (same as --color never)',
  );
  stdout.writeln(
    '  --ascii                        Use ASCII character fallback formatting',
  );
  stdout.writeln(
    '  --severity-threshold <sev>     Minimum severity filter: critical, high, medium, low, info',
  );
  stdout.writeln(
    '  --confidence-threshold <val>   Minimum confidence threshold filter (0.0 to 1.0)',
  );
  stdout.writeln(
    '  --rule <id>                    Filter issues by specific rule ID',
  );
  stdout.writeln(
    '  --category <cat>               Filter issues by diagnostic category',
  );
  stdout.writeln(
    '  --exclude <pattern>            Exclude files matching substring pattern',
  );
  stdout.writeln(
    '  --max-issues <n>               Limit max number of reported issues',
  );
  stdout.writeln(
    '  --no-ai                        Disable optional AI provider enrichment',
  );
  stdout.writeln(
    '  --verbose                      Print detailed execution diagnostics and stack traces',
  );
  stdout.writeln('  --quiet                        Suppress stdout output');
  stdout.writeln('  --help, -h                     Show this help message');
  stdout.writeln('  --version, -v                  Show package version');
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln('  dart run flutter_dev_intelligence doctor --project .');
  stdout.writeln(
    '  dart run flutter_dev_intelligence ui-doctor --project=. --format=json',
  );
  stdout.writeln(
    '  dart run flutter_dev_intelligence build-doctor --log=android_build.log',
  );
  stdout.writeln(
    '  cat trace.json | dart run flutter_dev_intelligence performance --stdin',
  );
  stdout.writeln(
    '  dart run flutter_dev_intelligence perf-investigator --trace=devtools_trace.json',
  );
}
