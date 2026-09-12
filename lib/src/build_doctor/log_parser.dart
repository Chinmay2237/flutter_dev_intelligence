import '../core/models.dart';
import 'build_doctor_rule.dart';
import 'build_log_normalizer.dart';
import 'log_classification.dart';

/// Result of detailed build log parsing.
class BuildLogParseResult {
  const BuildLogParseResult({
    required this.issues,
    required this.classification,
    required this.normalizedLog,
  });

  final List<DiagnosticIssue> issues;
  final LogClassificationResult classification;
  final NormalizedLogResult normalizedLog;
}

/// Parses build log text into evidence-based issues and explicit log classification.
class BuildLogParser {
  const BuildLogParser({this.registry = const BuildDoctorRuleRegistry()});

  final BuildDoctorRuleRegistry registry;

  static List<DiagnosticIssue> parse(
    String log, {
    BuildDoctorRuleRegistry registry = const BuildDoctorRuleRegistry(),
    int maxLogSizeBytes = 10485760,
  }) {
    final result = parseDetailed(
      log,
      registry: registry,
      maxLogSizeBytes: maxLogSizeBytes,
    );
    return result.issues;
  }

  static BuildLogParseResult parseDetailed(
    String log, {
    BuildDoctorRuleRegistry registry = const BuildDoctorRuleRegistry(),
    int maxLogSizeBytes = 10485760,
  }) {
    final normalized = BuildLogNormalizer.normalize(
      log,
      maxLogSizeBytes: maxLogSizeBytes,
    );
    final matchedIssues = registry.analyze(normalized.cleanLog);

    final classification = LogClassifier.classify(
      rawLog: log,
      cleanLog: normalized.cleanLog,
      matchedIssues: matchedIssues,
    );

    final issues = <DiagnosticIssue>[...matchedIssues];

    // If no rules matched and log is not empty or clean, add fallback unknown issue with exact required wording
    if (issues.isEmpty &&
        classification.type != LogClassificationType.clean &&
        classification.type != LogClassificationType.empty) {
      issues.add(
        DiagnosticIssue(
          id: 'build.unknown-log-pattern',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.info,
          title: 'No known build issue detected',
          description:
              'The log was analyzed successfully, but no supported diagnostic pattern matched. This does not prove the build is healthy.',
          source: 'build log',
          evidence: [
            EvidenceReference(
              type: EvidenceType.log,
              label: 'build-log',
              value: normalized.cleanLog.substring(
                0,
                normalized.cleanLog.length > 240
                    ? 240
                    : normalized.cleanLog.length,
              ),
            ),
          ],
          suggestions: [
            FixSuggestion(
              action: classification.recommendation,
              details: classification.recommendation,
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: classification.confidence,
          limitation:
              'Analysis is limited to implemented deterministic build log rules.',
        ),
      );
    }

    return BuildLogParseResult(
      issues: issues,
      classification: classification,
      normalizedLog: normalized,
    );
  }
}
