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
    case 'ui_doctor':
    case 'ui':
    case 'inspect':
      final args = (command == 'ui' || command == 'ui_doctor')
          ? (arguments.length > 1 && arguments[1] == 'doctor'
                ? arguments.skip(2).toList()
                : arguments.skip(1).toList())
          : arguments.skip(1).toList();
      exitCode = await UiDoctorCli.run(args);
      return;

    case 'doctor':
    case 'doc':
      exitCode = await _runBuildDoctor(arguments.skip(1).toList());
      return;

    default:
      if (!command.startsWith('-') &&
          (File(command).existsSync() || Directory(command).existsSync())) {
        exitCode = await _runBuildDoctor(arguments);
      } else {
        stderr.writeln("Error: Unknown command or input '$command'.");
        stderr.writeln(
          "Run 'flutter_dev_intelligence --help' for available commands.",
        );
        exitCode = 2;
      }
      return;
  }
}

Future<int> _runBuildDoctor(List<String> arguments) async {
  final options = _parseArgs(arguments);
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
    stderr.writeln('  flutter_dev_intelligence build-doctor --log <path>');
    stderr.writeln('  flutter_dev_intelligence build-doctor --stdin');
    return 2;
  }

  try {
    final projectName = await _resolveProjectName(options.projectPath);
    final configResult = await ProjectConfig.findAndLoad(options.projectPath);

    final report = await BuildDoctorEngine.analyze(
      options: BuildDoctorEngineOptions(
        logPath: sourceLabel,
        logContent: logContent,
        projectName: projectName,
        projectPath: options.projectPath,
        redactSecrets: !options.noRedact,
        config: configResult.config,
      ),
    );

    return await _renderAndOutput(report, options);
  } catch (error, stack) {
    stderr.writeln('Error: Diagnostic execution failed: $error');
    if (options.verbose) stderr.writeln(stack);
    return 3;
  }
}

Future<String> _resolveProjectName(String projectPath) async {
  try {
    final pubspec = await PubspecAnalyzer.analyze(projectPath);
    if (pubspec.packageName.isNotEmpty) {
      return pubspec.packageName;
    }
  } catch (_) {}
  final dir = Directory(projectPath);
  final basename = dir.absolute.path
      .replaceAll(RegExp(r'[/\\]+$'), '')
      .split(Platform.pathSeparator)
      .last;
  return (basename.isEmpty || basename == '.') ? 'flutter-project' : basename;
}

Future<String> _readStdin() async {
  return await systemEncoding.decodeStream(stdin);
}

class _CliOptions {
  _CliOptions({
    required this.projectPath,
    this.logPath,
    this.format = 'terminal',
    this.outputPath,
    this.quiet = false,
    this.verbose = false,
    this.useStdin = false,
    this.useAscii = false,
    this.noRedact = false,
    this.colorMode = ColorMode.auto,
    this.errorExitCode,
  });

  final String projectPath;
  final String? logPath;
  final String format;
  final String? outputPath;
  final bool quiet;
  final bool verbose;
  final bool useStdin;
  final bool useAscii;
  final bool noRedact;
  final ColorMode colorMode;
  final int? errorExitCode;
}

_CliOptions _parseArgs(List<String> arguments) {
  var projectPath = Directory.current.path;
  String? logPath;
  var format = 'terminal';
  String? outputPath;
  var quiet = false;
  var verbose = false;
  var useStdin = false;
  var useAscii = false;
  var noRedact = false;
  var colorMode = ColorMode.auto;

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
      '--log',
      '--format',
      '--output',
      '--color',
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
      case '--log':
        logPath = value!;
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
      case '--no-redact':
        noRedact = true;
        break;
      default:
        if (!flag.startsWith('-') && logPath == null) {
          logPath = flag;
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

  return _CliOptions(
    projectPath: projectPath,
    logPath: logPath,
    format: format,
    outputPath: outputPath,
    quiet: quiet,
    verbose: verbose,
    useStdin: useStdin,
    useAscii: useAscii,
    noRedact: noRedact,
    colorMode: colorMode,
  );
}

Future<int> _renderAndOutput(
  DiagnosticReport report,
  _CliOptions options,
) async {
  final rendered = switch (options.format) {
    'json' => JsonReporter.render(report),
    'markdown' => MarkdownReporter.render(report),
    _ => TerminalReporter.render(
      report,
      colorMode: options.colorMode,
      useAscii: options.useAscii,
    ),
  };

  if (options.outputPath != null) {
    try {
      await File(options.outputPath!).parent.create(recursive: true);
      final fileContent =
          (options.format == 'terminal' &&
              options.colorMode != ColorMode.always)
          ? TerminalReporter.stripAnsi(rendered)
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

  final hasErrorOrCritical = report.findings.any(
    (finding) =>
        finding.severity == DiagnosticSeverity.error ||
        finding.severity == DiagnosticSeverity.critical,
  );

  return hasErrorOrCritical ? 1 : 0;
}

void _printHelp() {
  stdout.writeln('Flutter Dev Intelligence — Flutter Project Health & Diagnostics');
  stdout.writeln('');
  stdout.writeln(
    'Offline-first diagnostic toolkit that analyzes Flutter and Dart projects,',
  );
  stdout.writeln('build log failures, UI/UX accessibility gaps, and code health.');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln('  ui-doctor (or inspect)   Statically inspect Flutter UI, code health, accessibility & assets');
  stdout.writeln('  build-doctor             Analyze Flutter/Dart build logs for root causes & cascading errors');
  stdout.writeln('');
  stdout.writeln(
    'Usage: flutter_dev_intelligence <command> [options] (or dart run flutter_dev_intelligence <command> [options])',
  );
  stdout.writeln('');
  stdout.writeln('Options (build-doctor):');
  stdout.writeln('  --log <path>         Build log file path to analyze');
  stdout.writeln('  --stdin              Read build log input from standard input pipe');
  stdout.writeln('');
  stdout.writeln('Options (ui-doctor / inspect):');
  stdout.writeln('  --project <path>     Target Flutter project directory');
  stdout.writeln('  --scope <scope>      Analysis scope: all, ui, accessibility, performance, maintainability, assets');
  stdout.writeln('');
  stdout.writeln('General Options:');
  stdout.writeln(
    '  --format <format>    Output format: terminal, json, or markdown (default: terminal)',
  );
  stdout.writeln('  --output <path>      Write rendered output report to file');
  stdout.writeln(
    '  --color <mode>       Terminal color mode: auto, always, or never (default: auto)',
  );
  stdout.writeln('  --no-color           Disable terminal colors');
  stdout.writeln(
    '  --ascii              Use ASCII fallback character formatting',
  );
  stdout.writeln(
    '  --verbose            Print detailed execution diagnostic logs',
  );
  stdout.writeln('  --quiet              Suppress stdout output');
  stdout.writeln('  --help, -h           Show this help message');
  stdout.writeln('  --version, -v        Show package version');
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln('  dart run flutter_dev_intelligence ui-doctor');
  stdout.writeln('  dart run flutter_dev_intelligence inspect --scope=accessibility');
  stdout.writeln(
    '  dart run flutter_dev_intelligence build-doctor --log=build.log',
  );
  stdout.writeln(
    '  cat build.log | dart run flutter_dev_intelligence build-doctor --stdin',
  );
}
