import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('DiagnosticFinding & DiagnosticReport Models', () {
    test('DiagnosticFinding serializes to JSON and deserializes correctly', () {
      final finding = DiagnosticFinding(
        id: 'PUB_VERSION_SOLVING_FAILED',
        title: 'Pub Dependency Version Solving Failure',
        category: DiagnosticCategory.pubDependency,
        severity: DiagnosticSeverity.error,
        confidence: DiagnosticConfidence.high,
        summary: 'Dependency version conflict.',
        likelyCause: 'Incompatible constraint bounds.',
        evidence: const [
          EvidenceReference(
            label: 'Pub Log',
            value: 'Because package A depends on B',
          ),
        ],
        recommendations: const [
          FixSuggestion(action: 'Inspect pubspec.yaml constraints'),
        ],
        primaryStatus: PrimaryStatus.primary,
        classificationReason: 'Dependency failure is a prerequisite.',
      );

      final json = finding.toJson();
      expect(json['id'], equals('PUB_VERSION_SOLVING_FAILED'));
      expect(json['category'], equals('pubDependency'));
      expect(json['severity'], equals('error'));
      expect(json['confidence'], equals('high'));
      expect(json['primaryStatus'], equals('primary'));
      expect(finding.isPrimary, isTrue);

      final deserialized = DiagnosticFinding.fromJson(json);
      expect(deserialized.id, equals(finding.id));
      expect(deserialized.category, equals(finding.category));
      expect(deserialized.severity, equals(finding.severity));
      expect(deserialized.confidence, equals(finding.confidence));
      expect(deserialized.primaryStatus, equals(finding.primaryStatus));
      expect(deserialized.evidence.length, equals(1));
      expect(deserialized.recommendations.length, equals(1));
    });

    test(
      'DiagnosticReport serializes to JSON and generates Markdown correctly',
      () {
        final report = DiagnosticReport(
          id: 'report_123',
          createdAt: DateTime.parse('2026-09-12T12:00:00Z'),
          projectName: 'demo_app',
          commandName: 'build-doctor',
          findings: [
            DiagnosticFinding(
              id: 'GRADLE_DEPENDENCY_RESOLUTION_FAILED',
              title: 'Gradle Dependency Failure',
              category: DiagnosticCategory.androidGradle,
              severity: DiagnosticSeverity.error,
              confidence: DiagnosticConfidence.high,
              summary: 'Could not resolve com.example:lib',
              likelyCause: 'Missing repository URL.',
              primaryStatus: PrimaryStatus.primary,
            ),
            DiagnosticFinding(
              id: 'GRADLE_TASK_FAILED',
              title: 'Gradle Task Failure',
              category: DiagnosticCategory.generalBuild,
              severity: DiagnosticSeverity.error,
              confidence: DiagnosticConfidence.medium,
              summary: 'Task compileDebugJavaWithJavac failed.',
              likelyCause: 'Downstream build error.',
              primaryStatus: PrimaryStatus.cascading,
            ),
          ],
        );

        expect(report.primaryFindings.length, equals(1));
        expect(report.cascadingFindings.length, equals(1));
        expect(
          report.primaryFindings.first.id,
          equals('GRADLE_DEPENDENCY_RESOLUTION_FAILED'),
        );
        expect(report.cascadingFindings.first.id, equals('GRADLE_TASK_FAILED'));

        final json = report.toJson();
        expect(json['id'], equals('report_123'));
        expect(json['summary']['primary'], equals(1));
        expect(json['summary']['cascading'], equals(1));

        final markdown = report.toMarkdown();
        expect(
          markdown,
          contains('# Flutter Dev Intelligence Diagnostic Report'),
        );
        expect(markdown, contains('## Primary Suspected Issues'));
        expect(markdown, contains('GRADLE_DEPENDENCY_RESOLUTION_FAILED'));
        expect(markdown, contains('## Cascading / Secondary Failures'));
        expect(markdown, contains('GRADLE_TASK_FAILED'));
      },
    );
  });
}
