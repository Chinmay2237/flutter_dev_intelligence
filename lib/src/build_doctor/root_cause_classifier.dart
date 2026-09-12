import '../core/models.dart';

class RootCauseClassifier {
  static List<DiagnosticFinding> classify(List<DiagnosticFinding> rawFindings) {
    if (rawFindings.isEmpty) return const [];

    // Check if any specific, non-generic rule matched in the log
    final hasSpecificRule = rawFindings.any(
      (f) => f.id != 'GRADLE_TASK_FAILED',
    );

    final primaryIds = rawFindings
        .where((f) => f.id != 'GRADLE_TASK_FAILED')
        .map((f) => f.id)
        .toList();

    final classified = <DiagnosticFinding>[];

    for (final finding in rawFindings) {
      PrimaryStatus status;
      String reason;

      if (finding.id == 'GRADLE_TASK_FAILED') {
        if (hasSpecificRule) {
          status = PrimaryStatus.cascading;
          reason = 'Cascading failure resulting from earlier specific error.';
        } else {
          status = PrimaryStatus.unknown;
          reason =
              'Generic task failure with no explicit upstream root cause detected.';
        }
      } else {
        status = PrimaryStatus.primary;
        reason = 'Specific failure root cause detected in build log.';
      }

      classified.add(
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
          primaryStatus: status,
          classificationReason: reason,
          relatedFindingIds: status == PrimaryStatus.cascading
              ? primaryIds
              : finding.relatedFindingIds,
          filePath: finding.filePath,
          line: finding.line,
          source: finding.source,
        ),
      );
    }

    return classified;
  }
}
