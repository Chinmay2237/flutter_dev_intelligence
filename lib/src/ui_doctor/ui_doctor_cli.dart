import 'dart:convert';
import 'dart:io';

import '../build_doctor/reporting.dart';
import '../core/models.dart';
import '../core/project_config.dart';
import 'ui_doctor_engine.dart';

/// CLI handler for the `ui-doctor` command.
class UiDoctorCli {
  const UiDoctorCli._();

  /// Runs the UI Doctor CLI command with provided [arguments].
  static Future<int> run(List<String> arguments) async {
    final options = _parseArgs(arguments);
    if (options.errorExitCode != null) return options.errorExitCode!;

    final targetDir = Directory(options.projectPath);
    if (!targetDir.existsSync()) {
      stderr.writeln(
        'Error: Project directory not found: ${options.projectPath}',
      );
      return 2;
    }

    DiagnosticReport? baselineReport;
    if (options.baselinePath != null) {
      final bFile = File(options.baselinePath!);
      if (!bFile.existsSync()) {
        stderr.writeln(
          'Error: Baseline file not found: ${options.baselinePath}',
        );
        return 2;
      }
      try {
        final bContent = await bFile.readAsString();
        final bJson = jsonDecode(bContent) as Map<String, dynamic>;
        baselineReport = DiagnosticReport.fromJson(bJson);
      } catch (e) {
        stderr.writeln(
          'Error: Failed to parse baseline file: ${options.baselinePath} ($e)',
        );
        return 2;
      }
    }

    ProjectConfig? customConfig;
    if (options.configPath != null) {
      final cFile = File(options.configPath!);
      if (!cFile.existsSync()) {
        stderr.writeln('Error: Config file not found: ${options.configPath}');
        return 2;
      }
      try {
        final cContent = await cFile.readAsString();
        final valRes = ProjectConfig.parseYaml(
          cContent,
          sourcePath: cFile.path,
        );
        if (!valRes.isValid) {
          stderr.writeln(
            'Error: Config validation failed: ${valRes.errors.join(', ')}',
          );
          return 2;
        }
        customConfig = valRes.config;
      } catch (e) {
        stderr.writeln(
          'Error: Failed to load config file: ${options.configPath} ($e)',
        );
        return 2;
      }
    }

    try {
      final report = await UiDoctorEngine.analyze(
        UiDoctorEngineOptions(
          projectPath: options.projectPath,
          scope: options.scope,
          config: customConfig,
          baselineReport: baselineReport,
          baselinePath: options.baselinePath,
        ),
      );

      if (options.generateBaselinePath != null) {
        final genPath = options.generateBaselinePath!;
        await File(genPath).parent.create(recursive: true);
        await File(genPath).writeAsString('${JsonReporter.render(report)}\n');
        if (!options.quiet) {
          stdout.writeln('Baseline snapshot saved successfully to $genPath');
        }
        return 0;
      }

      return await _renderAndOutput(report, options);
    } catch (error, stack) {
      stderr.writeln('Error: UI Doctor execution failed: $error');
      if (options.verbose) stderr.writeln(stack);
      return 3;
    }
  }

  static _UiCliOptions _parseArgs(List<String> arguments) {
    var projectPath = Directory.current.path;
    var scope = 'all';
    var format = 'terminal';
    String? outputPath;
    String? configPath;
    String? baselinePath;
    String? generateBaselinePath;
    var failOnNew = true;
    var quiet = false;
    var verbose = false;
    var useAscii = false;
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
        '--scope',
        '--format',
        '--output',
        '--config',
        '--baseline',
        '--generate-baseline',
        '--color',
      };

      if (valueFlags.contains(flag) && value == null) {
        if (flag == '--baseline' || flag == '--generate-baseline') {
          if (index + 1 < arguments.length &&
              !arguments[index + 1].startsWith('-')) {
            value = arguments[++index];
          } else {
            value = '.flutter_dev_intelligence_baseline.json';
          }
        } else {
          if (index + 1 >= arguments.length) {
            stderr.writeln('Error: Missing value for $flag.');
            return _UiCliOptions(projectPath: projectPath, errorExitCode: 2);
          }
          value = arguments[++index];
        }
      }

      switch (flag) {
        case '--help':
        case '-h':
          _printHelp();
          return _UiCliOptions(projectPath: projectPath, errorExitCode: 0);

        case '--project':
          projectPath = value!;
          break;

        case '--scope':
          scope = value!.toLowerCase();
          break;

        case '--format':
          format = value!.toLowerCase();
          break;

        case '--output':
          outputPath = value!;
          break;

        case '--config':
          configPath = value!;
          break;

        case '--baseline':
          baselinePath = value ?? '.flutter_dev_intelligence_baseline.json';
          break;

        case '--generate-baseline':
          generateBaselinePath =
              value ?? '.flutter_dev_intelligence_baseline.json';
          break;

        case '--fail-on-new':
          failOnNew = true;
          break;

        case '--no-fail-on-new':
          failOnNew = false;
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
              return _UiCliOptions(projectPath: projectPath, errorExitCode: 2);
          }
          break;

        case '--no-color':
          colorMode = ColorMode.never;
          break;

        case '--ascii':
          useAscii = true;
          break;

        case '--verbose':
          verbose = true;
          break;

        case '--quiet':
          quiet = true;
          break;

        default:
          stderr.writeln('Error: Unknown option for ui-doctor: $flag');
          return _UiCliOptions(projectPath: projectPath, errorExitCode: 2);
      }
    }

    if (!const {'terminal', 'json', 'markdown'}.contains(format)) {
      stderr.writeln(
        'Error: Unsupported output format: $format. Choose terminal, json, or markdown.',
      );
      return _UiCliOptions(projectPath: projectPath, errorExitCode: 2);
    }

    if (!const {
      'all',
      'ui',
      'accessibility',
      'performance',
      'maintainability',
      'assets',
    }.contains(scope)) {
      stderr.writeln(
        'Error: Unsupported scope: $scope. Choose all, ui, accessibility, performance, maintainability, or assets.',
      );
      return _UiCliOptions(projectPath: projectPath, errorExitCode: 2);
    }

    return _UiCliOptions(
      projectPath: projectPath,
      scope: scope,
      format: format,
      outputPath: outputPath,
      configPath: configPath,
      baselinePath: baselinePath,
      generateBaselinePath: generateBaselinePath,
      failOnNew: failOnNew,
      quiet: quiet,
      verbose: verbose,
      useAscii: useAscii,
      colorMode: colorMode,
    );
  }

  static Future<int> _renderAndOutput(
    DiagnosticReport report,
    _UiCliOptions options,
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

    if (options.baselinePath != null &&
        options.failOnNew &&
        report.baseline?.status == 'FAILED') {
      return 1;
    }

    final hasErrorOrCritical = report.findings.any(
      (finding) =>
          finding.severity == DiagnosticSeverity.error ||
          finding.severity == DiagnosticSeverity.critical,
    );

    return hasErrorOrCritical ? 1 : 0;
  }

  static void _printHelp() {
    stdout.writeln(
      'Flutter Dev Intelligence — UI Doctor (Static UI/UX & Code Health)',
    );
    stdout.writeln('');
    stdout.writeln(
      'Statically inspects Flutter source code and asset configuration to identify',
    );
    stdout.writeln(
      'potential UI, accessibility, maintainability, and performance code smells.',
    );
    stdout.writeln('');
    stdout.writeln('Usage: flutter_dev_intelligence ui-doctor [options]');
    stdout.writeln('');
    stdout.writeln('Options:');
    stdout.writeln(
      '  --project <path>             Target Flutter project directory (default: current directory)',
    );
    stdout.writeln(
      '  --scope <scope>              Analysis scope: all, ui, accessibility, performance, maintainability, assets (default: all)',
    );
    stdout.writeln(
      '  --format <format>            Output format: terminal, json, or markdown (default: terminal)',
    );
    stdout.writeln(
      '  --output <path>              Write report output to specified file path',
    );
    stdout.writeln(
      '  --config <path>              Path to configuration YAML file',
    );
    stdout.writeln(
      '  --baseline[=<path>]          Compare findings against saved baseline snapshot file',
    );
    stdout.writeln(
      '  --generate-baseline[=<path>] Save current findings as a baseline JSON snapshot',
    );
    stdout.writeln(
      '  --fail-on-new / --no-fail-on-new Return exit code 1 if new baseline issues exist (default: true)',
    );
    stdout.writeln(
      '  --color <mode>               Terminal color mode: auto, always, or never (default: auto)',
    );
    stdout.writeln(
      '  --no-color                   Disable terminal color formatting',
    );
    stdout.writeln(
      '  --ascii                      Use ASCII characters for layout formatting',
    );
    stdout.writeln(
      '  --verbose                    Print detailed execution traces',
    );
    stdout.writeln('  --quiet                      Suppress standard output');
    stdout.writeln('  --help, -h                   Show this help message');
    stdout.writeln('');
    stdout.writeln('Examples:');
    stdout.writeln('  dart run flutter_dev_intelligence ui-doctor');
    stdout.writeln('  dart run flutter_dev_intelligence ui-doctor --baseline');
    stdout.writeln(
      '  dart run flutter_dev_intelligence ui-doctor --generate-baseline',
    );
    stdout.writeln(
      '  dart run flutter_dev_intelligence ui-doctor --format=json --output=ui-report.json',
    );
  }
}

class _UiCliOptions {
  _UiCliOptions({
    required this.projectPath,
    this.scope = 'all',
    this.format = 'terminal',
    this.outputPath,
    this.configPath,
    this.baselinePath,
    this.generateBaselinePath,
    this.failOnNew = true,
    this.quiet = false,
    this.verbose = false,
    this.useAscii = false,
    this.colorMode = ColorMode.auto,
    this.errorExitCode,
  });

  final String projectPath;
  final String scope;
  final String format;
  final String? outputPath;
  final String? configPath;
  final String? baselinePath;
  final String? generateBaselinePath;
  final bool failOnNew;
  final bool quiet;
  final bool verbose;
  final bool useAscii;
  final ColorMode colorMode;
  final int? errorExitCode;
}
