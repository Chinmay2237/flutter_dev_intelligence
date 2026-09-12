import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectConfig & DiagnosticFilter Unit Tests', () {
    test('Default ProjectConfig initializes correctly', () {
      const config = ProjectConfig();
      expect(config.version, equals(1));
      expect(config.severityThreshold, equals(DiagnosticSeverity.info));
      expect(config.confidenceThreshold, equals(0.0));
      expect(config.redactSecrets, isTrue);
    });

    test('DiagnosticFilter filters findings below severity threshold', () {
      const config = ProjectConfig(severityThreshold: DiagnosticSeverity.error);

      final findings = [
        DiagnosticFinding(
          id: 'INFO_RULE',
          title: 'Info Rule',
          category: DiagnosticCategory.generalBuild,
          severity: DiagnosticSeverity.info,
          confidence: DiagnosticConfidence.high,
          summary: 'Info text',
          likelyCause: 'Cause',
        ),
        DiagnosticFinding(
          id: 'ERROR_RULE',
          title: 'Error Rule',
          category: DiagnosticCategory.pubDependency,
          severity: DiagnosticSeverity.error,
          confidence: DiagnosticConfidence.high,
          summary: 'Error text',
          likelyCause: 'Cause',
        ),
      ];

      final filtered = DiagnosticFilter.filterIssues(findings, config);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('ERROR_RULE'));
    });
  });
}
