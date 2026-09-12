import '../core/models.dart';
import 'log_parser.dart';

/// Build-focused diagnostics for local project or build log analysis.
class BuildDoctor {
  const BuildDoctor();

  /// Parses a raw build log and returns a high-confidence issue when a clear pattern is found.
  static DiagnosticIssue detectIssueFromLog(String log) {
    final parseResult = BuildLogParser.parseDetailed(log);
    if (parseResult.issues.isNotEmpty) {
      return parseResult.issues.first;
    }

    return DiagnosticIssue(
      id: 'build_log_analysis',
      category: DiagnosticCategory.build,
      severity: DiagnosticSeverity.info,
      title: 'No known build issue detected',
      description:
          'The log was analyzed successfully, but no supported diagnostic pattern matched. This does not prove the build is healthy.',
      evidence: [
        EvidenceReference(
          type: EvidenceType.log,
          label: 'build.log',
          value: log.substring(0, log.length > 220 ? 220 : log.length),
        ),
      ],
      suggestions: const [
        FixSuggestion(
          action: 'Inspect the full build output',
          details:
              'Review the complete build log and verify the failing command and dependency version constraints.',
        ),
      ],
      confidence: 0.35,
    );
  }
}
