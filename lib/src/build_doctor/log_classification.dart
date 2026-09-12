import '../core/models.dart';

/// Distinct classification categories for build logs.
enum LogClassificationType {
  empty,
  malformed,
  clean,
  knownIssue,
  unknownPattern,
  partialTruncated,
  mixedPlatform,
}

/// Result of log classification analysis.
class LogClassificationResult {
  const LogClassificationResult({
    required this.type,
    required this.confidence,
    required this.explanation,
    required this.recommendation,
  });

  final LogClassificationType type;
  final double confidence;
  final String explanation;
  final String recommendation;
}

/// Classifier for raw and normalized build logs.
class LogClassifier {
  const LogClassifier._();

  static LogClassificationResult classify({
    required String rawLog,
    required String cleanLog,
    required List<DiagnosticIssue> matchedIssues,
  }) {
    if (rawLog.trim().isEmpty) {
      return const LogClassificationResult(
        type: LogClassificationType.empty,
        confidence: 1.0,
        explanation: 'The provided build log is empty.',
        recommendation: 'Provide complete build output log text for analysis.',
      );
    }

    // Check for malformed binary content (e.g. NUL bytes or unprintable non-text controls)
    if (rawLog.contains('\x00') ||
        RegExp(r'[\x01-\x08\x0E-\x1F]').hasMatch(rawLog)) {
      return const LogClassificationResult(
        type: LogClassificationType.malformed,
        confidence: 0.95,
        explanation:
            'The build log appears to contain malformed or binary stream data.',
        recommendation:
            'Ensure the build output log is captured as UTF-8 encoded plain text.',
      );
    }

    final lower = cleanLog.toLowerCase();

    // Mixed platform check
    final hasAndroid = matchedIssues.any((i) => i.id.startsWith('android'));
    final hasIos = matchedIssues.any((i) => i.id.startsWith('ios'));
    if (hasAndroid && hasIos) {
      return LogClassificationResult(
        type: LogClassificationType.mixedPlatform,
        confidence: 0.9,
        explanation:
            'The build log contains diagnostic issues from both Android and iOS platform toolchains.',
        recommendation:
            'Address platform-specific issues sequentially, starting with primary root cause errors.',
      );
    }

    if (matchedIssues.isNotEmpty) {
      return LogClassificationResult(
        type: LogClassificationType.knownIssue,
        confidence: matchedIssues.first.confidence ?? 0.8,
        explanation:
            'Matched ${matchedIssues.length} known diagnostic build rule(s).',
        recommendation:
            'Follow specific recommendations provided in diagnostic issues.',
      );
    }

    // Clean log check: success indicators without failure keywords
    final hasSuccessIndicator =
        lower.contains('build successful') ||
        lower.contains('** build succeeded **') ||
        lower.contains('built build/app/outputs') ||
        lower.contains('0 errors, 0 warnings') ||
        lower.contains('0 errors');

    final hasFailureIndicator =
        lower.contains('failure:') ||
        lower.contains('failed') ||
        lower.contains('error:') ||
        lower.contains('exit code 1') ||
        lower.contains('exception');

    if (hasSuccessIndicator && !hasFailureIndicator) {
      return const LogClassificationResult(
        type: LogClassificationType.clean,
        confidence: 0.9,
        explanation:
            'The build output indicates a clean build execution without known errors.',
        recommendation: 'No action required for healthy builds.',
      );
    }

    if (lower.contains('truncated') || lower.contains('... [lines omitted]')) {
      return const LogClassificationResult(
        type: LogClassificationType.partialTruncated,
        confidence: 0.75,
        explanation: 'The build log appears to be truncated or incomplete.',
        recommendation:
            'Provide full un-truncated build logs for complete diagnostic analysis.',
      );
    }

    // Unknown pattern fallback
    return const LogClassificationResult(
      type: LogClassificationType.unknownPattern,
      confidence: 0.4,
      explanation:
          'The log was analyzed successfully, but no supported diagnostic pattern matched. This does not prove the build is healthy.',
      recommendation:
          'Inspect the full build output and task logs if the build or analysis still fails.',
    );
  }
}
