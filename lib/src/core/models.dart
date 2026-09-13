import 'config.dart';

/// Severity level for diagnostic findings.
enum DiagnosticSeverity {
  info,
  warning,
  error,
  critical;

  static DiagnosticSeverity fromString(String value) {
    switch (value.toLowerCase()) {
      case 'info':
        return DiagnosticSeverity.info;
      case 'warning':
      case 'low':
      case 'medium':
        return DiagnosticSeverity.warning;
      case 'error':
      case 'high':
        return DiagnosticSeverity.error;
      case 'critical':
        return DiagnosticSeverity.critical;
      default:
        return DiagnosticSeverity.error;
    }
  }
}

/// Confidence classification based on strength of matched evidence.
enum DiagnosticConfidence {
  high,
  medium,
  low,
  unknown;

  static DiagnosticConfidence fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return DiagnosticConfidence.high;
      case 'medium':
        return DiagnosticConfidence.medium;
      case 'low':
        return DiagnosticConfidence.low;
      case 'unknown':
      default:
        return DiagnosticConfidence.unknown;
    }
  }
}

/// Diagnostic categories supported by the diagnostic engine.
enum DiagnosticCategory {
  pubDependency('Pub & Dependency Resolution'),
  dartCompiler('Dart Compiler'),
  androidGradle('Android & Gradle'),
  iosCocoaPods('iOS & CocoaPods'),
  buildEnvironment('Build Environment & Toolchain'),
  generalBuild('General Build Failure');

  const DiagnosticCategory(this.displayName);
  final String displayName;

  static DiagnosticCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pubdependency':
      case 'dependency':
      case 'pub':
        return DiagnosticCategory.pubDependency;
      case 'dartcompiler':
      case 'compiler':
      case 'dart':
        return DiagnosticCategory.dartCompiler;
      case 'androidgradle':
      case 'gradle':
      case 'android':
      case 'java':
      case 'kotlin':
        return DiagnosticCategory.androidGradle;
      case 'ioscocoapods':
      case 'cocoapods':
      case 'ios':
      case 'xcode':
        return DiagnosticCategory.iosCocoaPods;
      case 'buildenvironment':
      case 'environment':
      case 'sdk':
        return DiagnosticCategory.buildEnvironment;
      case 'generalbuild':
      case 'build':
      default:
        return DiagnosticCategory.generalBuild;
    }
  }
}

/// Classification of finding in the root-cause analysis chain.
enum PrimaryStatus {
  primary,
  cascading,
  independent,
  unknown;

  static PrimaryStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'primary':
        return PrimaryStatus.primary;
      case 'cascading':
      case 'secondary':
        return PrimaryStatus.cascading;
      case 'independent':
        return PrimaryStatus.independent;
      case 'unknown':
      default:
        return PrimaryStatus.unknown;
    }
  }
}

/// Evidence item supporting a diagnostic finding.
class EvidenceReference {
  final String label;
  final String value;
  final String type;
  final int? lineNumber;
  final Map<String, dynamic>? metadata;

  const EvidenceReference({
    required this.label,
    required this.value,
    this.type = 'log',
    this.lineNumber,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'type': type,
    if (lineNumber != null) 'lineNumber': lineNumber,
    if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
  };

  factory EvidenceReference.fromJson(Map<String, dynamic> json) {
    return EvidenceReference(
      label: json['label'] as String? ?? 'Evidence',
      value: json['value'] as String? ?? '',
      type: json['type'] as String? ?? 'log',
      lineNumber: json['lineNumber'] is int
          ? json['lineNumber'] as int
          : (json['line'] is int ? json['line'] as int : null),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// Actionable fix recommendation.
class FixSuggestion {
  final String action;
  final String details;

  const FixSuggestion({required this.action, this.details = ''});

  Map<String, dynamic> toJson() => {'action': action, 'details': details};

  factory FixSuggestion.fromJson(Map<String, dynamic> json) {
    return FixSuggestion(
      action:
          json['action'] as String? ??
          json['step'] as String? ??
          'Review the issue',
      details: json['details'] as String? ?? '',
    );
  }
}

/// A single evidence-based diagnostic finding.
class DiagnosticFinding {
  final String id;
  final String title;
  final DiagnosticCategory category;
  final DiagnosticSeverity severity;
  final DiagnosticConfidence confidence;
  final String summary;
  final String likelyCause;
  final List<EvidenceReference> evidence;
  final List<FixSuggestion> recommendations;
  final PrimaryStatus primaryStatus;
  final String? classificationReason;
  final List<String> relatedFindingIds;
  final String? filePath;
  final int? line;
  final String source;
  final String? baselineStatus;

  const DiagnosticFinding({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.confidence,
    required this.summary,
    required this.likelyCause,
    this.evidence = const <EvidenceReference>[],
    this.recommendations = const <FixSuggestion>[],
    this.primaryStatus = PrimaryStatus.unknown,
    this.classificationReason,
    this.relatedFindingIds = const <String>[],
    this.filePath,
    this.line,
    this.source = 'build_doctor',
    this.baselineStatus,
  });

  bool get isPrimary => primaryStatus == PrimaryStatus.primary;
  bool get isCascading => primaryStatus == PrimaryStatus.cascading;

  /// Fingerprint string uniquely identifying this finding across runs (ruleId:filePath:location).
  String get fingerprint {
    final path = (filePath ?? 'project').replaceAll('\\', '/');
    final loc = line != null ? '$line' : (evidence.isNotEmpty ? evidence.first.value : '0');
    return '$id:$path:$loc';
  }

  /// Compatibility alias for description.
  String get description => summary;

  /// Compatibility alias for suggestions.
  List<FixSuggestion> get suggestions => recommendations;

  /// Backward-compatibility numeric confidence accessor (1.0 = high, 0.7 = medium, 0.4 = low, 0.0 = unknown).
  double get confidenceScore => switch (confidence) {
    DiagnosticConfidence.high => 1.0,
    DiagnosticConfidence.medium => 0.7,
    DiagnosticConfidence.low => 0.4,
    DiagnosticConfidence.unknown => 0.0,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'severity': severity.name,
    'confidence': confidence.name,
    'summary': summary,
    'likelyCause': likelyCause,
    'evidence': evidence.map((e) => e.toJson()).toList(),
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'primaryStatus': primaryStatus.name,
    if (classificationReason != null)
      'classificationReason': classificationReason,
    'relatedFindingIds': relatedFindingIds,
    if (filePath != null) 'filePath': filePath,
    if (line != null) 'line': line,
    'source': source,
    if (baselineStatus != null) 'baselineStatus': baselineStatus,
    'isPrimary': isPrimary,
  };

  factory DiagnosticFinding.fromJson(Map<String, dynamic> json) {
    return DiagnosticFinding(
      id: json['id'] as String? ?? 'UNKNOWN_RULE',
      title: json['title'] as String? ?? 'Unknown Issue',
      category: DiagnosticCategory.fromString(
        json['category']?.toString() ?? 'generalBuild',
      ),
      severity: DiagnosticSeverity.fromString(
        json['severity']?.toString() ?? 'error',
      ),
      confidence: DiagnosticConfidence.fromString(
        json['confidence']?.toString() ?? 'unknown',
      ),
      summary:
          json['summary'] as String? ?? json['description'] as String? ?? '',
      likelyCause: json['likelyCause'] as String? ?? '',
      evidence: ((json['evidence'] as List?) ?? const [])
          .map(
            (e) =>
                EvidenceReference.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      recommendations:
          ((json['recommendations'] as List?) ??
                  (json['suggestions'] as List?) ??
                  const [])
              .map(
                (r) =>
                    FixSuggestion.fromJson(Map<String, dynamic>.from(r as Map)),
              )
              .toList(),
      primaryStatus: PrimaryStatus.fromString(
        json['primaryStatus']?.toString() ?? 'unknown',
      ),
      classificationReason: json['classificationReason'] as String?,
      relatedFindingIds: ((json['relatedFindingIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      filePath: json['filePath'] as String?,
      line: json['line'] as int?,
      source: json['source'] as String? ?? 'build_doctor',
      baselineStatus: json['baselineStatus'] as String?,
    );
  }
}

/// Baseline comparison results when comparing a report to a baseline snapshot.
class BaselineComparison {
  final String baselinePath;
  final String status;
  final int totalBaselineFindings;
  final int newCount;
  final int resolvedCount;
  final int unchangedCount;
  final List<String> newFindingIds;

  const BaselineComparison({
    required this.baselinePath,
    required this.status,
    required this.totalBaselineFindings,
    required this.newCount,
    required this.resolvedCount,
    required this.unchangedCount,
    this.newFindingIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'baselinePath': baselinePath,
    'status': status,
    'totalBaselineFindings': totalBaselineFindings,
    'newCount': newCount,
    'resolvedCount': resolvedCount,
    'unchangedCount': unchangedCount,
    'newFindingIds': newFindingIds,
  };

  factory BaselineComparison.fromJson(Map<String, dynamic> json) {
    return BaselineComparison(
      baselinePath: json['baselinePath'] as String? ?? '',
      status: json['status'] as String? ?? 'PASSED',
      totalBaselineFindings: json['totalBaselineFindings'] as int? ?? 0,
      newCount: json['newCount'] as int? ?? 0,
      resolvedCount: json['resolvedCount'] as int? ?? 0,
      unchangedCount: json['unchangedCount'] as int? ?? 0,
      newFindingIds: ((json['newFindingIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Typedef alias for backward compatibility with existing tests/callers.
typedef DiagnosticIssue = DiagnosticFinding;

/// Comprehensive diagnostic report containing findings, summary, and metadata.
class DiagnosticReport {
  final String id;
  final DateTime createdAt;
  final String projectName;
  final String? projectPath;
  final String commandName;
  final String analyzerType;
  final String analysisStatus;
  final List<DiagnosticFinding> findings;
  final List<String> unrecognizedLogLines;
  final List<String> warnings;
  final List<String> limitations;
  final String toolName;
  final String toolVersion;
  final String schemaVersion;
  final List<String> analyzedSources;
  final int? durationMs;
  final int? rulesExecuted;
  final BaselineComparison? baseline;

  const DiagnosticReport({
    required this.id,
    required this.createdAt,
    required this.projectName,
    this.projectPath,
    this.commandName = 'build-doctor',
    this.analyzerType = 'BuildDoctorEngine',
    this.analysisStatus = 'completed',
    this.findings = const <DiagnosticFinding>[],
    this.unrecognizedLogLines = const <String>[],
    this.warnings = const <String>[],
    this.limitations = const <String>[],
    this.toolName = 'flutter_dev_intelligence',
    this.toolVersion = kPackageVersion,
    this.schemaVersion = '1.0',
    this.analyzedSources = const <String>[],
    this.durationMs,
    this.rulesExecuted,
    this.baseline,
  });

  /// Compatibility alias for issues.
  List<DiagnosticFinding> get issues => findings;

  List<DiagnosticFinding> get primaryFindings =>
      findings.where((f) => f.primaryStatus == PrimaryStatus.primary).toList();

  List<DiagnosticFinding> get cascadingFindings => findings
      .where((f) => f.primaryStatus == PrimaryStatus.cascading)
      .toList();

  List<DiagnosticFinding> get independentFindings => findings
      .where(
        (f) =>
            f.primaryStatus == PrimaryStatus.independent ||
            f.primaryStatus == PrimaryStatus.unknown,
      )
      .toList();

  Map<String, int> get severityCounts {
    final counts = <String, int>{};
    for (final finding in findings) {
      counts[finding.severity.name] = (counts[finding.severity.name] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'tool': {'name': toolName, 'version': toolVersion},
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'projectName': projectName,
    if (projectPath != null) 'projectPath': projectPath,
    'commandName': commandName,
    'analyzerType': analyzerType,
    'analysisStatus': analysisStatus,
    'summary': {
      'total': findings.length,
      'primary': primaryFindings.length,
      'cascading': cascadingFindings.length,
      'critical': severityCounts['critical'] ?? 0,
      'error': severityCounts['error'] ?? 0,
      'warning': severityCounts['warning'] ?? 0,
      'info': severityCounts['info'] ?? 0,
    },
    'findings': findings.map((f) => f.toJson()).toList(),
    'issues': findings.map((f) => f.toJson()).toList(),
    'unrecognizedLogLinesCount': unrecognizedLogLines.length,
    'unrecognizedLogLines': unrecognizedLogLines,
    'warnings': warnings,
    'limitations': limitations,
    'analyzedSources': analyzedSources,
    if (durationMs != null) 'durationMs': durationMs,
    if (rulesExecuted != null) 'rulesExecuted': rulesExecuted,
    if (baseline != null) 'baseline': baseline!.toJson(),
  };

  factory DiagnosticReport.fromJson(Map<String, dynamic> json) {
    final toolMap = json['tool'] is Map ? (json['tool'] as Map) : null;
    final name =
        toolMap?['name']?.toString() ??
        json['toolName']?.toString() ??
        'flutter_dev_intelligence';
    final version =
        toolMap?['version']?.toString() ??
        json['toolVersion']?.toString() ??
        kPackageVersion;

    final findingsRaw =
        (json['findings'] as List?) ?? (json['issues'] as List?) ?? const [];
    final findingsList = findingsRaw
        .map(
          (entry) => DiagnosticFinding.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList();

    final baselineJson = json['baseline'] is Map ? (json['baseline'] as Map) : null;
    final baselineComp = baselineJson != null
        ? BaselineComparison.fromJson(Map<String, dynamic>.from(baselineJson))
        : null;

    return DiagnosticReport(
      id: json['id'] as String? ?? 'report',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      projectName: json['projectName'] as String? ?? 'flutter-project',
      projectPath: json['projectPath'] as String?,
      commandName: json['commandName'] as String? ?? 'build-doctor',
      analyzerType: json['analyzerType'] as String? ?? 'BuildDoctorEngine',
      analysisStatus: json['analysisStatus'] as String? ?? 'completed',
      findings: findingsList,
      unrecognizedLogLines:
          ((json['unrecognizedLogLines'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      limitations: ((json['limitations'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      toolName: name,
      toolVersion: version,
      schemaVersion: json['schemaVersion'] as String? ?? '1.0',
      analyzedSources: ((json['analyzedSources'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      durationMs: json['durationMs'] as int?,
      rulesExecuted: json['rulesExecuted'] as int?,
      baseline: baselineComp,
    );
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Flutter Dev Intelligence Diagnostic Report');
    buffer.writeln('**Project:** `$projectName`');
    buffer.writeln('**Generated:** `${createdAt.toIso8601String()}`');
    buffer.writeln('**Tool Version:** `$toolName $toolVersion`');
    buffer.writeln();

    buffer.writeln('## Summary');
    buffer.writeln('- **Total Findings:** ${findings.length}');
    buffer.writeln('- **Primary Root Causes:** ${primaryFindings.length}');
    buffer.writeln('- **Cascading Errors:** ${cascadingFindings.length}');
    buffer.writeln();

    if (primaryFindings.isNotEmpty) {
      buffer.writeln('## Primary Suspected Issues');
      for (final finding in primaryFindings) {
        _writeFindingMarkdown(buffer, finding);
      }
    }

    if (cascadingFindings.isNotEmpty) {
      buffer.writeln('## Cascading / Secondary Failures');
      for (final finding in cascadingFindings) {
        _writeFindingMarkdown(buffer, finding);
      }
    }

    if (independentFindings.isNotEmpty &&
        primaryFindings.isEmpty &&
        cascadingFindings.isEmpty) {
      buffer.writeln('## Diagnostic Findings');
      for (final finding in independentFindings) {
        _writeFindingMarkdown(buffer, finding);
      }
    }

    if (findings.isEmpty) {
      buffer.writeln('> No build errors or diagnostic issues detected.');
      buffer.writeln();
    }

    if (unrecognizedLogLines.isNotEmpty) {
      buffer.writeln('## Unrecognized Output Summary');
      buffer.writeln(
        'The log contained ${unrecognizedLogLines.length} unrecognized lines.',
      );
      buffer.writeln();
    }

    if (limitations.isNotEmpty) {
      buffer.writeln('## Limitations');
      for (final lim in limitations) {
        buffer.writeln('- $lim');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  static void _writeFindingMarkdown(
    StringBuffer buffer,
    DiagnosticFinding finding,
  ) {
    buffer.writeln('### ${finding.title}');
    buffer.writeln('- **Rule ID:** `${finding.id}`');
    buffer.writeln('- **Category:** ${finding.category.displayName}');
    buffer.writeln('- **Severity:** ${finding.severity.name.toUpperCase()}');
    buffer.writeln(
      '- **Confidence:** ${finding.confidence.name.toUpperCase()}',
    );
    if (finding.classificationReason != null) {
      buffer.writeln(
        '- **Classification:** ${finding.primaryStatus.name} (${finding.classificationReason})',
      );
    }
    buffer.writeln();
    buffer.writeln('**Summary:** ${finding.summary}');
    buffer.writeln();
    buffer.writeln('**Likely Cause:** ${finding.likelyCause}');
    buffer.writeln();

    if (finding.evidence.isNotEmpty) {
      buffer.writeln('**Evidence:**');
      for (final ev in finding.evidence) {
        buffer.writeln('```text');
        buffer.writeln('${ev.label}: ${ev.value}');
        buffer.writeln('```');
      }
      buffer.writeln();
    }

    if (finding.recommendations.isNotEmpty) {
      buffer.writeln('**Recommended Actions:**');
      for (var i = 0; i < finding.recommendations.length; i++) {
        final rec = finding.recommendations[i];
        buffer.writeln(
          '${i + 1}. ${rec.action}${rec.details.isNotEmpty ? " - ${rec.details}" : ""}',
        );
      }
      buffer.writeln();
    }
  }
}
