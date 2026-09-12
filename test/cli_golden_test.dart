import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('CLI Golden Output Contract Tests', () {
    test('JSON output matches contract schema structure', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_dev_intelligence.dart',
        'build-doctor',
        '--log=test/fixtures/build_logs/gradle_dependency_failure.log',
        '--format=json',
      ]);

      final stdoutText = result.stdout.toString();
      expect(stdoutText, contains('"schemaVersion"'));
      expect(stdoutText, contains('"tool"'));
      expect(stdoutText, contains('"id"'));
      expect(stdoutText, contains('"createdAt"'));
      expect(stdoutText, contains('"projectName"'));
      expect(stdoutText, contains('"summary"'));
      expect(stdoutText, contains('"findings"'));
      expect(stdoutText, contains('"primaryStatus"'));
    });
  });
}
