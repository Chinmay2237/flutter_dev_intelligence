import 'dart:io';

import '../core/config.dart';
import '../core/models.dart';
import 'build_doctor_engine.dart';
import 'pubspec_analyzer.dart';

/// Options controlling project diagnosis.
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

/// Runs build log & project diagnostics.
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

    final pubspec = await PubspecAnalyzer.analyze(options.projectPath);

    if (options.logPath != null && File(options.logPath!).existsSync()) {
      return BuildDoctorEngine.analyze(
        options: BuildDoctorEngineOptions(
          logPath: options.logPath,
          projectName: pubspec.packageName.isNotEmpty
              ? pubspec.packageName
              : 'flutter-project',
          projectPath: options.projectPath,
          redactSecrets: effectiveConfig.redactSecrets,
          maxLogSizeBytes: effectiveConfig.maxLogSizeBytes,
        ),
      );
    }

    return DiagnosticReport(
      id: 'doctor_${started.microsecondsSinceEpoch}',
      createdAt: started,
      projectName: pubspec.packageName.isNotEmpty
          ? pubspec.packageName
          : 'flutter-project',
      projectPath: options.projectPath,
      commandName: 'doctor',
      analyzerType: 'DoctorRunner',
      analysisStatus: 'completed',
      findings: const [],
      warnings: const [
        'No log file provided. Pass --log <path> to analyze build logs.',
      ],
      durationMs: DateTime.now().difference(started).inMilliseconds,
    );
  }
}
