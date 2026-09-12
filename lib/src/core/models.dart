import 'config.dart';

/// Severity ranking for diagnostic findings.
enum DiagnosticSeverity { info, low, medium, high, critical }

/// Diagnostic categories supported by the library.
enum DiagnosticCategory {
  build,
  dependency,
  gradle,
  kotlin,
  java,
  ios,
  xcode,
  cocoapods,
  layout,
  responsive,
  accessibility,
  localization,
  visual,
  performance,
  startup,
  frame,
  rebuild,
  network,
  memory,
  architecture,
}

/// Evidence source types used in reports.
enum EvidenceType {
  log,
  sourceFile,
  screenshot,
  screenshotDiff,
  widgetTree,
  semanticTree,
  timeline,
  frameTiming,
  performanceMetric,
  networkTrace,
  memorySnapshot,
  dependencyGraph,
  environment,
  configuration,
}

/// Reference for how a diagnosis was derived.
class EvidenceReference {
  final EvidenceType type;
  final String label;
  final String value;
  final Map<String, dynamic>? metadata;

  const EvidenceReference({
    required this.type,
    required this.label,
    required this.value,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'value': value,
    'metadata': metadata ?? const <String, dynamic>{},
  };

  factory EvidenceReference.fromJson(Map<String, dynamic> json) {
    return EvidenceReference(
      type: EvidenceType.values.byName(json['type'] as String? ?? 'log'),
      label: json['label'] as String? ?? 'evidence',
      value: json['value'] as String? ?? '',
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// Risk levels for proposed automated or manual fixes.
enum FixRiskLevel { low, medium, high }

/// Concrete suggestion to fix an issue with risk and automation metadata.
class FixSuggestion {
  final String action;
  final String details;
  final FixRiskLevel riskLevel;
  final String? proposedChange;
  final bool isSafeToAutomate;
  final bool requiresUserConfirmation;

  const FixSuggestion({
    required this.action,
    required this.details,
    this.riskLevel = FixRiskLevel.low,
    this.proposedChange,
    this.isSafeToAutomate = false,
    this.requiresUserConfirmation = true,
  });

  Map<String, dynamic> toJson() => {
    'action': action,
    'details': details,
    'riskLevel': riskLevel.name,
    'proposedChange': proposedChange,
    'isSafeToAutomate': isSafeToAutomate,
    'requiresUserConfirmation': requiresUserConfirmation,
  };

  factory FixSuggestion.fromJson(Map<String, dynamic> json) {
    return FixSuggestion(
      action: json['action'] as String? ?? 'Review the issue',
      details: json['details'] as String? ?? '',
      riskLevel: FixRiskLevel.values.byName(
        json['riskLevel'] as String? ?? 'low',
      ),
      proposedChange: json['proposedChange'] as String?,
      isSafeToAutomate: json['isSafeToAutomate'] as bool? ?? false,
      requiresUserConfirmation:
          json['requiresUserConfirmation'] as bool? ?? true,
    );
  }
}

/// Validation result for diagnostic recommendations.
class ValidationResult {
  final bool passed;
  final String message;

  const ValidationResult({required this.passed, required this.message});

  Map<String, dynamic> toJson() => {'passed': passed, 'message': message};

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      passed: json['passed'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

/// A single, evidence-backed diagnosis.
class DiagnosticIssue {
  final String id;
  final DiagnosticCategory category;
  final DiagnosticSeverity severity;
  final String title;
  final String description;
  final String? filePath;
  final int? line;
  final List<EvidenceReference> evidence;
  final List<FixSuggestion> suggestions;
  final double? confidence;
  final ValidationResult? validation;
  final String source;
  final String? limitation;

  const DiagnosticIssue({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    this.filePath,
    this.line,
    this.evidence = const <EvidenceReference>[],
    this.suggestions = const <FixSuggestion>[],
    this.confidence,
    this.validation,
    this.source = 'unknown',
    this.limitation,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'severity': severity.name,
    'title': title,
    'description': description,
    'filePath': filePath,
    'line': line,
    'evidence': evidence.map((entry) => entry.toJson()).toList(),
    'suggestions': suggestions.map((entry) => entry.toJson()).toList(),
    'confidence': confidence,
    'validation': validation?.toJson(),
    'source': source,
    'limitation': limitation,
  };

  factory DiagnosticIssue.fromJson(Map<String, dynamic> json) {
    return DiagnosticIssue(
      id: json['id'] as String? ?? 'unknown_issue',
      category: DiagnosticCategory.values.byName(
        json['category'] as String? ?? 'build',
      ),
      severity: DiagnosticSeverity.values.byName(
        json['severity'] as String? ?? 'medium',
      ),
      title: json['title'] as String? ?? 'Unknown issue',
      description: json['description'] as String? ?? '',
      filePath: json['filePath'] as String?,
      line: json['line'] as int?,
      evidence: ((json['evidence'] as List?) ?? const [])
          .map(
            (entry) => EvidenceReference.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      suggestions: ((json['suggestions'] as List?) ?? const [])
          .map(
            (entry) =>
                FixSuggestion.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(),
      confidence: json['confidence'] as double?,
      validation: json['validation'] == null
          ? null
          : ValidationResult.fromJson(
              Map<String, dynamic>.from(json['validation'] as Map),
            ),
      source: json['source'] as String? ?? 'unknown',
      limitation: json['limitation'] as String?,
    );
  }
}

/// A collection of diagnostics for a project or session.
class DiagnosticReport {
  final String id;
  final DateTime createdAt;
  final String projectName;
  final List<DiagnosticIssue> issues;
  final Map<String, dynamic> metrics;
  final List<String> warnings;
  final String toolName;
  final String toolVersion;
  final String schemaVersion;
  final String? projectPath;
  final List<String> analyzedSources;
  final List<String> limitations;
  final List<String> skippedAnalyses;
  final List<String> unavailableAnalyses;
  final int? durationMs;
  final int? filesAnalyzed;
  final int? rulesExecuted;

  const DiagnosticReport({
    required this.id,
    required this.createdAt,
    required this.projectName,
    this.issues = const <DiagnosticIssue>[],
    this.metrics = const <String, dynamic>{},
    this.warnings = const <String>[],
    this.toolName = 'flutter_dev_intelligence',
    this.toolVersion = kPackageVersion,
    this.schemaVersion = '1.0',
    this.projectPath,
    this.analyzedSources = const <String>[],
    this.limitations = const <String>[],
    this.skippedAnalyses = const <String>[],
    this.unavailableAnalyses = const <String>[],
    this.durationMs,
    this.filesAnalyzed,
    this.rulesExecuted,
  });

  Map<String, int> get severityCounts {
    final counts = <String, int>{};
    for (final issue in issues) {
      counts[issue.severity.name] = (counts[issue.severity.name] ?? 0) + 1;
    }
    return counts;
  }

  Map<DiagnosticSeverity, List<DiagnosticIssue>> get issuesBySeverity {
    final grouped = <DiagnosticSeverity, List<DiagnosticIssue>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.severity, () => <DiagnosticIssue>[]).add(issue);
    }
    return grouped;
  }

  Map<String, List<DiagnosticIssue>> get issuesBySource {
    final grouped = <String, List<DiagnosticIssue>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.source, () => <DiagnosticIssue>[]).add(issue);
    }
    return grouped;
  }

  Map<DiagnosticCategory, List<DiagnosticIssue>> get issuesByCategory {
    final grouped = <DiagnosticCategory, List<DiagnosticIssue>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.category, () => <DiagnosticIssue>[]).add(issue);
    }
    return grouped;
  }

  Map<String, dynamic> toJson() {
    final critical = severityCounts['critical'] ?? 0;
    final high = severityCounts['high'] ?? 0;
    final medium = severityCounts['medium'] ?? 0;
    final low = severityCounts['low'] ?? 0;
    final info = severityCounts['info'] ?? 0;
    final actionable = critical + high + medium;

    return {
      'schemaVersion': schemaVersion,
      'tool': {'name': toolName, 'version': toolVersion},
      'analysis': {
        'status': issues.isEmpty
            ? 'completed'
            : (actionable > 0 ? 'actionable' : 'completed'),
        if (durationMs != null) 'durationMs': durationMs,
        if (filesAnalyzed != null) 'filesAnalyzed': filesAnalyzed,
        if (rulesExecuted != null) 'rulesExecuted': rulesExecuted,
      },
      'summary': {
        'critical': critical,
        'high': high,
        'medium': medium,
        'low': low,
        'info': info,
        'actionable': actionable,
        'total': issues.length,
      },
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'projectName': projectName,
      if (projectPath != null) 'projectPath': projectPath,
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'metrics': metrics,
      'warnings': warnings,
      'toolName': toolName,
      'toolVersion': toolVersion,
      'analyzedSources': analyzedSources,
      'limitations': limitations,
      'skippedAnalyses': skippedAnalyses,
      'unavailableAnalyses': unavailableAnalyses,
      if (durationMs != null) 'durationMs': durationMs,
      if (filesAnalyzed != null) 'filesAnalyzed': filesAnalyzed,
      if (rulesExecuted != null) 'rulesExecuted': rulesExecuted,
      'severityCounts': severityCounts,
    };
  }

  factory DiagnosticReport.fromJson(Map<String, dynamic> json) {
    final toolMap = json['tool'] is Map ? (json['tool'] as Map) : null;
    final analysisMap = json['analysis'] is Map
        ? (json['analysis'] as Map)
        : null;

    final name =
        toolMap?['name']?.toString() ??
        json['toolName']?.toString() ??
        'flutter_dev_intelligence';
    final version =
        toolMap?['version']?.toString() ??
        json['toolVersion']?.toString() ??
        kPackageVersion;

    final dur =
        (analysisMap?['durationMs'] as int?) ?? (json['durationMs'] as int?);
    final files =
        (analysisMap?['filesAnalyzed'] as int?) ??
        (json['filesAnalyzed'] as int?);
    final rules =
        (analysisMap?['rulesExecuted'] as int?) ??
        (json['rulesExecuted'] as int?);

    return DiagnosticReport(
      id: json['id'] as String? ?? 'report',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      projectName: json['projectName'] as String? ?? 'unknown-project',
      issues: ((json['issues'] as List?) ?? const [])
          .map(
            (entry) => DiagnosticIssue.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      metrics: (json['metrics'] as Map? ?? const {}).cast<String, dynamic>(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      toolName: name,
      toolVersion: version,
      schemaVersion: json['schemaVersion'] as String? ?? '1.0',
      projectPath: json['projectPath'] as String?,
      analyzedSources: ((json['analyzedSources'] as List?) ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      limitations: ((json['limitations'] as List?) ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      skippedAnalyses: ((json['skippedAnalyses'] as List?) ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      unavailableAnalyses: ((json['unavailableAnalyses'] as List?) ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      durationMs: dur,
      filesAnalyzed: files,
      rulesExecuted: rules,
    );
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# $projectName Diagnostic Report');
    buffer.writeln('Tool: $toolName $toolVersion');
    if (projectPath != null) {
      buffer.writeln('Project: $projectPath');
    }
    buffer.writeln('Generated: ${createdAt.toIso8601String()}');
    buffer.writeln('Issues: ${issues.length}');
    buffer.writeln();
    buffer.writeln('## Issues');
    if (issues.isEmpty) {
      buffer.writeln('- No issues detected.');
    } else {
      for (final issue in issues) {
        buffer.writeln('- ${issue.title} (${issue.severity.name})');
      }
    }
    if (limitations.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Limitations');
      for (final limitation in limitations) {
        buffer.writeln('- $limitation');
      }
    }
    if (skippedAnalyses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Skipped Analyses');
      for (final analysis in skippedAnalyses) {
        buffer.writeln('- $analysis');
      }
    }
    if (unavailableAnalyses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Unavailable Analyses');
      for (final analysis in unavailableAnalyses) {
        buffer.writeln('- $analysis');
      }
    }
    return buffer.toString();
  }
}
