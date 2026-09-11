#!/usr/bin/env dart

import 'dart:io';

import 'package:flutter_dev_intelligence/src/build_doctor/doctor_runner.dart';
import 'package:flutter_dev_intelligence/src/build_doctor/reporting.dart';

Future<void> main(List<String> arguments) async {
  final command = arguments.isEmpty ? 'help' : arguments.first;

  switch (command) {
    case 'help':
    case '--help':
    case '-h':
      _printHelp();
      exitCode = 0;
      return;
    case 'doctor':
      exitCode = await _runDoctor(arguments.skip(1).toList());
      return;
    case 'build-doctor':
    case 'build':
      if (command == 'build' && arguments.length <= 1) {
        _printHelp();
        exitCode = 2;
        return;
      }
      final buildArguments = command == 'build'
          ? arguments.skip(2).toList()
          : arguments.skip(1).toList();
      exitCode = await _runDoctor(buildArguments, requireLog: true);
      return;
    case '--version':
    case '-v':
      stdout.writeln('flutter_dev_intelligence 0.0.1');
      exitCode = 0;
      return;
    default:
      _printHelp();
      exitCode = 2;
      return;
  }
}

Future<int> _runDoctor(
  List<String> arguments, {
  bool requireLog = false,
}) async {
  var projectPath = Directory.current.path;
  String? logPath;
  String format = 'terminal';
  String? outputPath;
  var quiet = false;
  var verbose = false;

  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    String? value;
    if (argument == '--project' ||
        argument == '--log' ||
        argument == '--format' ||
        argument == '--output') {
      if (index + 1 >= arguments.length) {
        stderr.writeln('Missing value for $argument.');
        return 2;
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
        break;
      default:
        if (!argument.startsWith('-') && arguments.length == 1) {
          projectPath = argument;
        } else {
          stderr.writeln('Unknown option: $argument');
          return 2;
        }
    }
  }

  if (!const {'terminal', 'json', 'markdown'}.contains(format)) {
    stderr.writeln('Unsupported output format: $format');
    return 2;
  }
  if (requireLog && logPath == null) {
    stderr.writeln('Build Doctor requires --log <path>.');
    return 2;
  }

  if (!await Directory(projectPath).exists()) {
    stderr.writeln('Project directory not found: $projectPath');
    return 2;
  }

  try {
    final report = await DoctorRunner.run(
      DoctorOptions(projectPath: projectPath, logPath: logPath),
    );
    final rendered = switch (format) {
      'json' => DiagnosticReportRenderer.renderJson(report),
      'markdown' => DiagnosticReportRenderer.renderMarkdown(report),
      _ => DiagnosticReportRenderer.renderTerminal(report),
    };

    if (outputPath != null) {
      await File(outputPath).parent.create(recursive: true);
      await File(outputPath).writeAsString('$rendered\n');
    } else if (!quiet) {
      stdout.write(rendered);
      if (!rendered.endsWith('\n')) {
        stdout.writeln();
      }
    }
    if (verbose && !quiet && format == 'terminal') {
      stdout.writeln('Analyzed sources: ${report.analyzedSources.join(', ')}');
    }

    return report.issues.isEmpty ? 0 : 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Unable to write report: ${error.message}');
    return 3;
  } catch (error) {
    stderr.writeln('Diagnostic execution failed: $error');
    return 3;
  }
}

void _printHelp() {
  stdout.writeln('Flutter Dev Intelligence CLI');
  stdout.writeln('');
  stdout.writeln('Usage: flutter-dev <command>');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln('  doctor          Run project diagnostics');
  stdout.writeln('  build-doctor    Run build-log diagnostics');
  stdout.writeln('');
  stdout.writeln('Doctor options:');
  stdout.writeln(
    '  --project <path>   Project root (default: current directory)',
  );
  stdout.writeln('  --log <path>       Optional build log');
  stdout.writeln('  --format <name>    terminal, json, or markdown');
  stdout.writeln('  --output <path>    Write the report to a file');
  stdout.writeln('  --verbose          Include execution details');
  stdout.writeln('  --quiet            Suppress report output');
  stdout.writeln('  --no-ai            Disable optional AI enrichment');
  stdout.writeln('  --help          Show this help output');
  stdout.writeln('  --version       Print package version');
}
