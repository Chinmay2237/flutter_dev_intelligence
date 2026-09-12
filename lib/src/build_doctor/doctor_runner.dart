import 'dart:io';

import '../core/config.dart';
import '../core/models.dart';
import 'log_parser.dart';
import 'project_scanner.dart';
import 'pubspec_analyzer.dart';
import 'pubspec_lock_analyzer.dart';
import '../ui_doctor/ui_ast_analyzer.dart';

/// Options controlling one deterministic project diagnosis.
class DoctorOptions {
  const DoctorOptions({
    required this.projectPath,
    this.logPath,
    this.configPath,
    this.includeUiDoctor = false,
  });

  final String projectPath;
  final String? logPath;
  final String? configPath;
  final bool includeUiDoctor;
}

/// Runs all available project-level diagnostics and combines their evidence.
class DoctorRunner {
  const DoctorRunner();

  static Future<DiagnosticReport> run(
    DoctorOptions options, {
    ProjectConfig? config,
  }) async {
    final started = DateTime.now();
    final effectiveConfig =
        config ??
        (await ProjectConfig.findAndLoad(
          options.projectPath,
          customConfigPath: options.configPath,
        )).config;

    final scan = await FlutterProjectScanner.scan(options.projectPath);
    final pubspec = await PubspecAnalyzer.analyze(options.projectPath);
    final lockfile = await PubspecLockAnalyzer.analyze(
      options.projectPath,
      expectedPackages: <String>[
        ...pubspec.dependencies,
        ...pubspec.devDependencies,
      ],
    );
    final rawIssues = <DiagnosticIssue>[];
    final warnings = <String>[];
    final skipped = <String>[];
    final unavailable = <String>[];
    final sources = <String>['project', 'pubspec', 'lockfile'];

    if (!scan.exists) {
      rawIssues.add(
        _issue(
          id: 'project_not_found',
          title: 'Project path not found',
          description: 'The requested project directory does not exist.',
          severity: DiagnosticSeverity.high,
          source: 'project',
          evidence: options.projectPath,
          suggestion: 'Provide an existing Flutter project path.',
        ),
      );
    } else if (!scan.hasPubspec) {
      rawIssues.add(
        _issue(
          id: 'pubspec_missing',
          title: 'pubspec.yaml is missing',
          description: 'The project directory does not contain pubspec.yaml.',
          severity: DiagnosticSeverity.high,
          source: 'pubspec',
          evidence: scan.path,
          suggestion: 'Run this command from a Dart or Flutter package root.',
        ),
      );
    } else if (!scan.isFlutterProject) {
      warnings.add(
        'pubspec.yaml was found, but this does not appear to be a Flutter project.',
      );
    }

    if (!lockfile.exists) {
      warnings.add(
        'pubspec.lock is missing; locked dependency consistency was skipped.',
      );
      skipped.add('lockfile consistency');
    }
    warnings.addAll(lockfile.warnings);

    if (options.includeUiDoctor &&
        scan.libFolderExists &&
        effectiveConfig.enableUiDoctor) {
      final uiResults = await UiAstAnalyzer.analyzeDirectory(
        '${scan.path}${Platform.pathSeparator}lib',
        config: effectiveConfig,
      );
      if (uiResults.isNotEmpty) {
        sources.add('static UI');
      }
      for (final result in uiResults) {
        rawIssues.addAll(result.issues);
        if (result.parseErrors.isNotEmpty) {
          warnings.add(
            'Static UI analysis could not fully parse ${result.filePath}: '
            '${result.parseErrors.join('; ')}',
          );
        }
      }
    } else {
      skipped.add('static UI analysis');
    }

    if (options.logPath == null) {
      skipped.add('build log analysis');
    } else {
      final logFile = File(options.logPath!);
      if (!await logFile.exists()) {
        rawIssues.add(
          _issue(
            id: 'build_log_missing',
            title: 'Build log not found',
            description: 'The supplied build log path does not exist.',
            severity: DiagnosticSeverity.high,
            source: 'build log',
            evidence: options.logPath!,
            suggestion: 'Provide a readable build log file.',
          ),
        );
      } else {
        sources.add('build log');
        try {
          final logContent = await logFile.readAsString();
          final parsed = BuildLogParser.parse(
            logContent,
            maxLogSizeBytes: effectiveConfig.maxLogSizeBytes,
          );
          rawIssues.addAll(
            parsed.map((issue) => _withSource(issue, 'build log')),
          );
        } catch (e) {
          warnings.add('Failed to parse build log file ${options.logPath}: $e');
        }
      }
    }

    skipped.add('performance trace analysis');

    unavailable.add(
      'AI explanation provider: disabled (no AI provider configured; deterministic analysis is active).',
    );
    final issues = DiagnosticFilter.filterIssues(rawIssues, effectiveConfig);
    return DiagnosticReport(
      id: 'doctor_${started.microsecondsSinceEpoch}',
      createdAt: started,
      projectName: pubspec.packageName.isNotEmpty
          ? pubspec.packageName
          : () {
              final absolutePath = Directory(options.projectPath).absolute.path;
              final basename = absolutePath
                  .replaceAll(RegExp(r'[/\\]+$'), '')
                  .split(Platform.pathSeparator)
                  .last;
              return (basename.isEmpty || basename == '.')
                  ? 'flutter-project'
                  : basename;
            }(),
      projectPath: options.projectPath,
      commandName: 'doctor',
      analyzerType: 'DoctorRunner',
      rulesExecuted: 10,
      issues: issues,
      metrics: <String, dynamic>{
        'dependency_count': pubspec.dependencies.length,
        'dev_dependency_count': pubspec.devDependencies.length,
        'locked_package_count': lockfile.packageCount,
      },
      warnings: warnings,
      analyzedSources: sources,
      limitations: const <String>[
        'Runtime frame timing requires execution inside a Flutter application and was not measured by this CLI run.',
        'Static UI findings are evaluated by the ui-doctor command.',
      ],
      skippedAnalyses: skipped,
      unavailableAnalyses: unavailable,
      durationMs: DateTime.now().difference(started).inMilliseconds,
    );
  }

  static DiagnosticIssue _withSource(DiagnosticIssue issue, String source) {
    return DiagnosticIssue(
      id: issue.id,
      category: issue.category,
      severity: issue.severity,
      title: issue.title,
      description: issue.description,
      filePath: issue.filePath,
      line: issue.line,
      evidence: issue.evidence,
      suggestions: issue.suggestions,
      confidence: issue.confidence,
      validation: issue.validation,
      source: source,
      limitation: issue.limitation,
    );
  }

  static DiagnosticIssue _issue({
    required String id,
    required String title,
    required String description,
    required DiagnosticSeverity severity,
    required String source,
    required String evidence,
    required String suggestion,
  }) {
    return DiagnosticIssue(
      id: id,
      category: DiagnosticCategory.build,
      severity: severity,
      title: title,
      description: description,
      source: source,
      evidence: [
        EvidenceReference(
          type: EvidenceType.configuration,
          label: source,
          value: evidence,
        ),
      ],
      suggestions: [FixSuggestion(action: suggestion, details: suggestion)],
      confidence: 1,
    );
  }
}
