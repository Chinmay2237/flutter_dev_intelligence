import 'dart:convert';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('JSON Schema Contract Tests', () {
    test('DiagnosticReport produces valid JSON conforming to contract', () {
      final report = DiagnosticReport(
        id: 'test_report_1',
        createdAt: DateTime.parse('2026-09-12T10:00:00Z'),
        projectName: 'schema_test',
        findings: [
          DiagnosticFinding(
            id: 'PUB_VERSION_SOLVING_FAILED',
            title: 'Pub Version Solving Failure',
            category: DiagnosticCategory.pubDependency,
            severity: DiagnosticSeverity.error,
            confidence: DiagnosticConfidence.high,
            summary: 'Version solving failed.',
            likelyCause: 'Incompatible constraint bounds.',
            primaryStatus: PrimaryStatus.primary,
          ),
        ],
      );

      final jsonStr = JsonReporter.render(report);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['schemaVersion'], equals('1.0'));
      expect(map['tool'], isA<Map>());
      expect(map['tool']['name'], equals('flutter_dev_intelligence'));
      expect(map['summary'], isA<Map>());
      expect(map['summary']['primary'], equals(1));
      expect(map['summary']['cascading'], equals(0));
      expect(map['findings'], isA<List>());
      expect(map['findings'].length, equals(1));
    });
  });
}
