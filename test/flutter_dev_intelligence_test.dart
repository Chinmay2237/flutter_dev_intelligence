import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('Flutter Dev Intelligence Integration Tests', () {
    test('Package initialization returns valid config', () {
      final config = FlutterDevIntelligence.initialize();
      expect(config.enableBuildDoctor, isTrue);
      expect(config.redactSecrets, isTrue);
    });

    test(
      'Full build doctor pipeline executes and returns structured report',
      () async {
        final logContent = '''
Target of URI doesn't exist: 'package:http/http.dart'.
import 'package:http/http.dart';
      ''';

        final report = await BuildDoctor.analyzeLog(logContent);
        expect(report.findings.isNotEmpty, isTrue);

        final finding = report.findings.first;
        expect(finding.id, equals('PUB_UNRESOLVED_PACKAGE'));
        expect(finding.severity, equals(DiagnosticSeverity.error));
        expect(finding.confidence, equals(DiagnosticConfidence.high));
        expect(finding.primaryStatus, equals(PrimaryStatus.primary));
      },
    );

    test('Redacts secrets from build log evidence', () async {
      final logContent = '''
Error accessing API endpoint with token ghp_1234567890abcdefghijklmnopqrstuvwxyz:
Target of URI doesn't exist: 'package:foo/foo.dart'.
      ''';

      final report = await BuildDoctor.analyzeLog(logContent);
      final json = report.toJson().toString();
      expect(json, isNot(contains('ghp_1234567890abcdefghijklmnopqrstuvwxyz')));
      expect(json, contains('[REDACTED_GITHUB_TOKEN]'));
    });
  });
}
