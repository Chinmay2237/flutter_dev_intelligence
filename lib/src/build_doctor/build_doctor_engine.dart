import '../core/models.dart';
import '../core/project_config.dart';
import 'input_loader.dart';
import 'log_normalizer.dart';
import 'log_parser.dart';
import 'diagnostic_rules.dart';
import 'rule_matcher.dart';
import 'root_cause_classifier.dart';

class BuildDoctorEngineOptions {
  final String? logPath;
  final String? logContent;
  final String projectName;
  final String? projectPath;
  final bool redactSecrets;
  final int maxLogSizeBytes;
  final List<DiagnosticRule>? customRules;
  final ProjectConfig? config;

  const BuildDoctorEngineOptions({
    this.logPath,
    this.logContent,
    this.projectName = 'flutter-project',
    this.projectPath,
    this.redactSecrets = true,
    this.maxLogSizeBytes = 10485760,
    this.customRules,
    this.config,
  });
}

class BuildDoctorEngine {
  const BuildDoctorEngine._();

  static Future<DiagnosticReport> analyze({
    required BuildDoctorEngineOptions options,
  }) async {
    final startTime = DateTime.now();

    // 1. Input Loading
    LogInputResult input;
    if (options.logContent != null) {
      input = InputLoader.fromString(
        options.logContent!,
        sourceLabel: options.logPath ?? 'stdin',
        maxSizeBytes: options.maxLogSizeBytes,
      );
    } else if (options.logPath != null) {
      input = await InputLoader.fromFile(
        options.logPath!,
        maxSizeBytes: options.maxLogSizeBytes,
      );
    } else {
      throw ArgumentError('Either logPath or logContent must be provided.');
    }

    // 2. Log Normalization
    final normalized = LogNormalizer.normalize(
      input.content,
      redactSecrets: options.redactSecrets,
    );

    // 3. Log Parsing & Event Extraction
    final parsed = LogParser.parse(normalized);

    // 4. Diagnostic Rule Matching
    final rawFindings = RuleMatcher.matchRules(
      normalized,
      parsed,
      rules: options.customRules,
    );

    // 5. Root Cause Classification (Primary vs Cascading)
    final classifiedFindings = RootCauseClassifier.classify(rawFindings);

    // 6. Apply Project Configuration Filters and Suppressions
    ProjectConfig? effectiveConfig = options.config;
    if (effectiveConfig == null &&
        options.projectPath != null &&
        options.projectPath!.isNotEmpty) {
      final configResult = await ProjectConfig.findAndLoad(
        options.projectPath!,
      );
      effectiveConfig = configResult.config;
    }

    final filteredFindings = effectiveConfig != null
        ? DiagnosticFilter.filterIssues(classifiedFindings, effectiveConfig)
        : classifiedFindings;

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    // 7. Report Generation
    final reportId = 'build_doctor_${DateTime.now().microsecondsSinceEpoch}';

    return DiagnosticReport(
      id: reportId,
      createdAt: startTime,
      projectName: options.projectName,
      projectPath: options.projectPath,
      commandName: 'build-doctor',
      analyzerType: 'BuildDoctorEngine',
      analysisStatus: filteredFindings.isEmpty ? 'completed' : 'actionable',
      findings: filteredFindings,
      unrecognizedLogLines: parsed.unrecognizedLines,
      analyzedSources: [input.sourceLabel],
      limitations: input.isTruncated
          ? [
              'Log exceeded size limit (${options.maxLogSizeBytes} bytes) and was truncated from head.',
            ]
          : const [
              'Build diagnostics are derived from log output analysis and do not re-execute build tools.',
            ],
      durationMs: durationMs,
      rulesExecuted:
          (options.customRules ?? DiagnosticRuleCatalog.allRules).length,
    );
  }
}
