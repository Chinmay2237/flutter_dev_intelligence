import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 4 Build Doctor Rule Registry Tests', () {
    test('Detects duplicate class from build log fixture', () async {
      final text = await File(
        'test/fixtures/build_logs/duplicate_class.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('duplicate_class'));
      final issue = issues.firstWhere((i) => i.id == 'duplicate_class');
      expect(issue.severity, DiagnosticSeverity.high);
      expect(issue.source, 'build log');
    });

    test('Detects Kotlin/Gradle mismatch from build log fixture', () async {
      final text = await File(
        'test/fixtures/build_logs/kotlin_gradle_mismatch.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('kotlin_gradle_mismatch'));
    });

    test('Detects AndroidManifest merge conflict', () async {
      final text = await File(
        'test/fixtures/build_logs/manifest_merge_error.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('manifest_merge_error'));
      final issue = issues.firstWhere((i) => i.id == 'manifest_merge_error');
      expect(issue.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Detects Swift compiler error in iOS build log', () async {
      final text = await File(
        'test/fixtures/build_logs/swift_compile_error.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('swift_compiler_error'));
    });

    test('Detects missing Android SDK components', () async {
      final text = await File(
        'test/fixtures/build_logs/android_sdk_missing.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('android_sdk_missing'));
    });

    test('Detects iOS code signing and CocoaPods issues', () async {
      final text = await File(
        'test/fixtures/build_logs/ios_signing.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('signing_configuration'));
    });

    test('Falls back to unknown_log_pattern for clean log output', () {
      final text = 'BUILD SUCCESSFUL in 12s\n27 actionable tasks: 27 executed';
      final issues = BuildLogParser.parse(text);

      expect(issues.length, 1);
      expect(issues.first.id, 'unknown_log_pattern');
      expect(issues.first.severity, DiagnosticSeverity.info);
      expect(issues.first.title, contains('No known build issue detected'));
    });

    test('Handles empty build log string gracefully', () {
      final issues = BuildLogParser.parse('');
      expect(issues, isEmpty);
    });
  });
}
