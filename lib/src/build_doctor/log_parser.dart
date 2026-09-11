import '../core/models.dart';

/// A single build log rule result.
class BuildLogRuleResult {
  const BuildLogRuleResult({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.description,
    required this.evidence,
    required this.suggestions,
    required this.confidence,
  });

  final String id;
  final String title;
  final DiagnosticCategory category;
  final DiagnosticSeverity severity;
  final String description;
  final List<String> evidence;
  final List<String> suggestions;
  final double confidence;

  DiagnosticIssue toIssue() {
    return DiagnosticIssue(
      id: id,
      category: category,
      severity: severity,
      title: title,
      description: description,
      evidence: evidence
          .map(
            (entry) => EvidenceReference(
              type: EvidenceType.log,
              label: 'build-log',
              value: entry,
            ),
          )
          .toList(),
      suggestions: suggestions
          .map((entry) => FixSuggestion(action: entry, details: entry))
          .toList(),
      confidence: confidence,
    );
  }
}

/// Parses build log text into a set of evidence-based issues.
class BuildLogParser {
  const BuildLogParser();

  static List<DiagnosticIssue> parse(String log) {
    if (log.trim().isEmpty) {
      return const <DiagnosticIssue>[];
    }

    final cleanLog = _normalizeLog(log);
    final issues = <DiagnosticIssue>[];

    if (cleanLog.toLowerCase().contains('kotlin') &&
        cleanLog.toLowerCase().contains('gradle') &&
        cleanLog.toLowerCase().contains('plugin')) {
      issues.add(
        BuildLogRuleResult(
          id: 'kotlin_gradle_mismatch',
          title: 'Potential Kotlin/Gradle compatibility issue',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.high,
          description:
              'The build log suggests a Kotlin and Android Gradle Plugin compatibility mismatch.',
          evidence: [
            cleanLog.substring(
              0,
              cleanLog.length > 220 ? 220 : cleanLog.length,
            ),
          ],
          suggestions: const [
            'Verify the Kotlin and Android Gradle Plugin versions are compatible.',
          ],
          confidence: 0.82,
        ).toIssue(),
      );
    }

    if (cleanLog.toLowerCase().contains('duplicate class')) {
      issues.add(
        BuildLogRuleResult(
          id: 'duplicate_class',
          title: 'Duplicate class detected',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.high,
          description:
              'The build log indicates that the same class appears in multiple dependency modules.',
          evidence: [
            cleanLog.substring(
              0,
              cleanLog.length > 220 ? 220 : cleanLog.length,
            ),
          ],
          suggestions: const [
            'Check dependencies and duplicate module/class entries in the Android build configuration.',
          ],
          confidence: 0.87,
        ).toIssue(),
      );
    }

    if (cleanLog.toLowerCase().contains('cannot find symbol') ||
        cleanLog.toLowerCase().contains('undefined identifier')) {
      issues.add(
        BuildLogRuleResult(
          id: 'compile_error',
          title: 'Source compilation error detected',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.medium,
          description:
              'The log indicates a Dart or Java/Kotlin compile error that may block the build.',
          evidence: [
            cleanLog.substring(
              0,
              cleanLog.length > 220 ? 220 : cleanLog.length,
            ),
          ],
          suggestions: const [
            'Review the exact compile error and verify imports, symbols, and generated code.',
          ],
          confidence: 0.72,
        ).toIssue(),
      );
    }

    final lowerLog = cleanLog.toLowerCase();
    if (lowerLog.contains('android sdk') &&
        (lowerLog.contains('not found') || lowerLog.contains('missing'))) {
      issues.add(
        BuildLogRuleResult(
          id: 'android_sdk_missing',
          title: 'Android SDK component may be missing',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.high,
          description:
              'The build output indicates that an Android SDK component could not be found.',
          evidence: [_evidence(cleanLog)],
          suggestions: const [
            'Install the required Android SDK component and verify ANDROID_HOME.',
          ],
          confidence: 0.86,
        ).toIssue(),
      );
    }

    if (lowerLog.contains('java home') ||
        lowerLog.contains('unsupported class file major version')) {
      issues.add(
        BuildLogRuleResult(
          id: 'java_runtime_mismatch',
          title: 'Java runtime compatibility issue',
          category: DiagnosticCategory.java,
          severity: DiagnosticSeverity.high,
          description:
              'The build output indicates an incompatible or unavailable Java runtime.',
          evidence: [_evidence(cleanLog)],
          suggestions: const [
            'Verify the configured JDK version and JAVA_HOME for the Flutter toolchain.',
          ],
          confidence: 0.8,
        ).toIssue(),
      );
    }

    if (lowerLog.contains('failed to resolve') ||
        lowerLog.contains('could not resolve') ||
        lowerLog.contains('version solving failed')) {
      issues.add(
        BuildLogRuleResult(
          id: 'dependency_resolution_failed',
          title: 'Dependency resolution failed',
          category: DiagnosticCategory.dependency,
          severity: DiagnosticSeverity.high,
          description:
              'The build output indicates that one or more dependencies could not be resolved.',
          evidence: [_evidence(cleanLog)],
          suggestions: const [
            'Review dependency constraints, package sources, and network access.',
          ],
          confidence: 0.84,
        ).toIssue(),
      );
    }

    if (lowerLog.contains('xcodebuild') || lowerLog.contains('xcode project')) {
      issues.add(
        BuildLogRuleResult(
          id: 'xcode_build_failure',
          title: 'Xcode build failure detected',
          category: DiagnosticCategory.xcode,
          severity: DiagnosticSeverity.high,
          description:
              'The output contains an Xcode build failure that requires platform-specific investigation.',
          evidence: [_evidence(cleanLog)],
          suggestions: const [
            'Review the first Xcode error and verify the installed Xcode and iOS SDK versions.',
          ],
          confidence: 0.7,
        ).toIssue(),
      );
    }

    if (lowerLog.contains('pod install') || lowerLog.contains('cocoapods')) {
      issues.add(
        BuildLogRuleResult(
          id: 'cocoapods_failure',
          title: 'CocoaPods issue detected',
          category: DiagnosticCategory.cocoapods,
          severity: DiagnosticSeverity.medium,
          description:
              'The output references CocoaPods and may require iOS dependency integration fixes.',
          evidence: [_evidence(cleanLog)],
          suggestions: const [
            'Run pod installation from the iOS directory and review the first CocoaPods error.',
          ],
          confidence: 0.68,
        ).toIssue(),
      );
    }

    if (lowerLog.contains('provisioning profile') ||
        lowerLog.contains('no profiles for') ||
        lowerLog.contains('code signing')) {
      issues.add(
        BuildLogRuleResult(
          id: 'signing_configuration',
          title: 'Signing configuration issue detected',
          category: DiagnosticCategory.ios,
          severity: DiagnosticSeverity.high,
          description:
              'The output indicates a code-signing or provisioning configuration problem.',
          evidence: [_evidence(cleanLog)],
          suggestions: const [
            'Check the target signing team, certificate, bundle identifier, and provisioning profile.',
          ],
          confidence: 0.82,
        ).toIssue(),
      );
    }

    if (issues.isEmpty) {
      issues.add(
        BuildLogRuleResult(
          id: 'unknown_log_pattern',
          title: 'No matching deterministic build issue detected',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.low,
          description:
              'The build output did not match the implemented deterministic rule set.',
          evidence: [
            cleanLog.substring(
              0,
              cleanLog.length > 220 ? 220 : cleanLog.length,
            ),
          ],
          suggestions: const [
            'Inspect the full build log and review the failing task output.',
          ],
          confidence: 0.25,
        ).toIssue(),
      );
    }

    return issues;
  }

  static String _normalizeLog(String log) {
    var normalized = log.replaceAll(RegExp(r'\u001b\[[0-9;]*m'), '');
    normalized = normalized.replaceAll(RegExp(r'\r\n?'), '\n');
    return normalized.trim();
  }

  static String _evidence(String log) {
    return log.substring(0, log.length > 220 ? 220 : log.length);
  }
}
