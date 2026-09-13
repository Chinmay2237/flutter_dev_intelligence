import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';

import '../build_doctor/pubspec_analyzer.dart';
import '../core/models.dart';
import '../core/project_config.dart';
import 'rules/accessibility_rules.dart';
import 'rules/asset_rules.dart';
import 'rules/code_health_rules.dart';
import 'rules/performance_rules.dart';
import 'rules/ui_rule_base.dart';

/// Options for configuring a UI Doctor analysis execution.
class UiDoctorEngineOptions {
  const UiDoctorEngineOptions({
    required this.projectPath,
    this.scope = 'all',
    this.projectName,
    this.config,
    this.baselineReport,
    this.baselinePath,
  });

  final String projectPath;
  final String scope;
  final String? projectName;
  final ProjectConfig? config;
  final DiagnosticReport? baselineReport;
  final String? baselinePath;
}

/// Analysis engine executing static UI, code health, accessibility, and asset diagnostics.
class UiDoctorEngine {
  /// Default set of registered UI Doctor rules.
  static final List<UiDoctorRule> defaultRules = [
    const AssetMissingFileRule(),
    const AssetCaseMismatchRule(),
    const AssetOversizedRule(),
    const DebugPrintInProdRule(),
    const LargeBuildMethodRule(),
    const LargeWidgetClassRule(),
    const ShrinkWrapInScrollableRule(),
    const AccessibilityMissingImageSemanticsRule(),
  ];

  static Future<DiagnosticReport> analyze(UiDoctorEngineOptions options) async {
    final stopwatch = Stopwatch()..start();
    final projectDir = Directory(options.projectPath);
    final absoluteProjectPath = projectDir.absolute.path;

    final configResult = await ProjectConfig.findAndLoad(absoluteProjectPath);
    final config = options.config ?? configResult.config;

    final pubspecResult = await PubspecAnalyzer.analyze(absoluteProjectPath);
    final resolvedProjectName = options.projectName ??
        (pubspecResult.packageName.isNotEmpty ? pubspecResult.packageName : _resolveDirName(absoluteProjectPath));

    final rulesToRun = defaultRules.where((rule) {
      if (options.scope == 'all' || options.scope.isEmpty) return true;
      return rule.scope.toLowerCase() == options.scope.toLowerCase();
    }).toList();

    final rawFindings = <DiagnosticFinding>[];
    final analyzedSources = <String>[];
    var ruleEvaluationsCount = 0;

    // 1. Run project-level analysis rules (pubspec & filesystem assets)
    for (final rule in rulesToRun) {
      ruleEvaluationsCount++;
      final findings = rule.analyzeProject(
        projectPath: absoluteProjectPath,
        pubspecResult: pubspecResult,
      );
      rawFindings.addAll(findings);
    }

    // 2. Scan Dart source files under lib/ directory
    final libDir = Directory('$absoluteProjectPath${Platform.pathSeparator}lib');
    if (libDir.existsSync()) {
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      for (final file in dartFiles) {
        final relPath = file.path.startsWith(absoluteProjectPath)
            ? file.path.substring(absoluteProjectPath.length).replaceAll(RegExp(r'^[/\\]+'), '')
            : file.path;

        if (config.shouldExcludePath(relPath)) continue;

        try {
          final content = await file.readAsString();
          if (content.trim().isEmpty) continue;

          analyzedSources.add(relPath);

          final parseResult = parseString(content: content, throwIfDiagnostics: false);
          final ast = parseResult.unit;

          for (final rule in rulesToRun) {
            ruleEvaluationsCount++;
            final findings = rule.analyzeDartFile(
              filePath: file.path,
              relativePath: relPath,
              content: content,
              ast: ast,
            );
            rawFindings.addAll(findings);
          }
        } catch (_) {
          // Gracefully continue on unparseable individual files
        }
      }
    }

    // 3. Apply project configuration filters and suppressions
    var filteredFindings = DiagnosticFilter.filterIssues(rawFindings, config);

    // 4. Perform baseline comparison if baselineReport is provided
    BaselineComparison? baselineComparison;
    if (options.baselineReport != null) {
      final baseline = options.baselineReport!;
      final baselineFingerprints = baseline.findings.map((f) => f.fingerprint).toSet();
      final currentFingerprints = filteredFindings.map((f) => f.fingerprint).toSet();

      final updatedFindings = <DiagnosticFinding>[];
      for (final finding in filteredFindings) {
        final status = baselineFingerprints.contains(finding.fingerprint) ? 'unchanged' : 'new';
        updatedFindings.add(
          DiagnosticFinding(
            id: finding.id,
            title: finding.title,
            category: finding.category,
            severity: finding.severity,
            confidence: finding.confidence,
            summary: finding.summary,
            likelyCause: finding.likelyCause,
            evidence: finding.evidence,
            recommendations: finding.recommendations,
            primaryStatus: finding.primaryStatus,
            classificationReason: finding.classificationReason,
            relatedFindingIds: finding.relatedFindingIds,
            filePath: finding.filePath,
            line: finding.line,
            source: finding.source,
            baselineStatus: status,
          ),
        );
      }
      filteredFindings = updatedFindings;

      final newFindings = updatedFindings.where((f) => f.baselineStatus == 'new').toList();
      final unchangedFindings = updatedFindings.where((f) => f.baselineStatus == 'unchanged').toList();
      final resolvedFindingIds = <String>[];
      for (final baselineFinding in baseline.findings) {
        if (!currentFingerprints.contains(baselineFinding.fingerprint)) {
          resolvedFindingIds.add(baselineFinding.id);
        }
      }

      final newCount = newFindings.length;
      final resolvedCount = resolvedFindingIds.length;
      final unchangedCount = unchangedFindings.length;
      final statusStr = newCount > 0 ? 'FAILED' : 'PASSED';

      baselineComparison = BaselineComparison(
        baselinePath: options.baselinePath ?? '.flutter_dev_intelligence_baseline.json',
        status: statusStr,
        totalBaselineFindings: baseline.findings.length,
        newCount: newCount,
        resolvedCount: resolvedCount,
        unchangedCount: unchangedCount,
        newFindingIds: newFindings.map((f) => f.id).toList(),
      );
    }

    stopwatch.stop();

    return DiagnosticReport(
      id: 'ui_doctor_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: resolvedProjectName,
      projectPath: absoluteProjectPath,
      commandName: 'ui-doctor',
      analyzerType: 'UiDoctorEngine',
      analysisStatus: 'completed',
      findings: filteredFindings,
      analyzedSources: analyzedSources,
      durationMs: stopwatch.elapsedMilliseconds,
      rulesExecuted: rulesToRun.length,
      filesScanned: analyzedSources.length,
      ruleEvaluations: ruleEvaluationsCount,
      baseline: baselineComparison,
    );
  }

  static String _resolveDirName(String path) {
    final normalized = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final lastSegment = normalized.split(Platform.pathSeparator).last;
    return (lastSegment.isEmpty || lastSegment == '.') ? 'flutter-project' : lastSegment;
  }
}
