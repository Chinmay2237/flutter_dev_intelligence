import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 1 Core Model Tests', () {
    test('FixSuggestion default values and JSON roundtrip', () {
      const defaultSuggestion = FixSuggestion(
        action: 'Refactor layout',
        details: 'Use Expanded widget',
      );

      expect(defaultSuggestion.riskLevel, FixRiskLevel.low);
      expect(defaultSuggestion.proposedChange, isNull);
      expect(defaultSuggestion.isSafeToAutomate, isFalse);
      expect(defaultSuggestion.requiresUserConfirmation, isTrue);

      final json = defaultSuggestion.toJson();
      expect(json['action'], 'Refactor layout');
      expect(json['details'], 'Use Expanded widget');
      expect(json['riskLevel'], 'low');
      expect(json['proposedChange'], isNull);
      expect(json['isSafeToAutomate'], isFalse);
      expect(json['requiresUserConfirmation'], isTrue);

      final restored = FixSuggestion.fromJson(json);
      expect(restored.action, 'Refactor layout');
      expect(restored.details, 'Use Expanded widget');
      expect(restored.riskLevel, FixRiskLevel.low);
      expect(restored.isSafeToAutomate, isFalse);
    });

    test('FixSuggestion custom risk and automation metadata', () {
      const customSuggestion = FixSuggestion(
        action: 'Remove duplicate class',
        details: 'Exclude module from gradle',
        riskLevel: FixRiskLevel.high,
        proposedChange: '- implementation "foo"\n+ // removed',
        isSafeToAutomate: false,
        requiresUserConfirmation: true,
      );

      final json = customSuggestion.toJson();
      expect(json['riskLevel'], 'high');
      expect(json['proposedChange'], contains('removed'));

      final restored = FixSuggestion.fromJson(json);
      expect(restored.riskLevel, FixRiskLevel.high);
      expect(restored.proposedChange, contains('removed'));
    });

    test('DiagnosticReport schema version and grouping helpers', () {
      final now = DateTime.now();
      final report = DiagnosticReport(
        id: 'test_report',
        createdAt: now,
        projectName: 'test_project',
        issues: const [
          DiagnosticIssue(
            id: 'issue_1',
            category: DiagnosticCategory.layout,
            severity: DiagnosticSeverity.high,
            title: 'High severity layout issue',
            description: 'Description 1',
            source: 'static UI',
          ),
          DiagnosticIssue(
            id: 'issue_2',
            category: DiagnosticCategory.layout,
            severity: DiagnosticSeverity.low,
            title: 'Low severity layout issue',
            description: 'Description 2',
            source: 'static UI',
          ),
          DiagnosticIssue(
            id: 'issue_3',
            category: DiagnosticCategory.build,
            severity: DiagnosticSeverity.high,
            title: 'High severity build issue',
            description: 'Description 3',
            source: 'build log',
          ),
        ],
      );

      expect(report.schemaVersion, '1.0');

      final json = report.toJson();
      expect(json['schemaVersion'], '1.0');

      final restored = DiagnosticReport.fromJson(json);
      expect(restored.schemaVersion, '1.0');

      // Check grouping helpers
      final bySeverity = report.issuesBySeverity;
      expect(bySeverity[DiagnosticSeverity.high]?.length, 2);
      expect(bySeverity[DiagnosticSeverity.low]?.length, 1);

      final bySource = report.issuesBySource;
      expect(bySource['static UI']?.length, 2);
      expect(bySource['build log']?.length, 1);

      final byCategory = report.issuesByCategory;
      expect(byCategory[DiagnosticCategory.layout]?.length, 2);
      expect(byCategory[DiagnosticCategory.build]?.length, 1);
    });

    test('Backward compatibility for legacy Json deserialization', () {
      final legacyFixJson = <String, dynamic>{
        'action': 'Legacy action',
        'details': 'Legacy details',
      };
      final restoredFix = FixSuggestion.fromJson(legacyFixJson);
      expect(restoredFix.action, 'Legacy action');
      expect(restoredFix.riskLevel, FixRiskLevel.low);
      expect(restoredFix.isSafeToAutomate, isFalse);

      final legacyReportJson = <String, dynamic>{
        'id': 'legacy_rep',
        'createdAt': DateTime.now().toIso8601String(),
        'projectName': 'legacy_project',
      };
      final restoredReport = DiagnosticReport.fromJson(legacyReportJson);
      expect(restoredReport.schemaVersion, '1.0');
    });
  });
}
