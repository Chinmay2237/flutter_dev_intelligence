import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Build Doctor Rule Registry Tests', () {
    test('Detects duplicate class from build log fixture', () async {
      final text = await File(
        'test/fixtures/build_logs/duplicate_class.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('android.duplicate-class'));
      final issue = issues.firstWhere((i) => i.id == 'android.duplicate-class');
      expect(issue.severity, DiagnosticSeverity.high);
      expect(issue.source, 'build log');
    });

    test('Detects Kotlin/Gradle mismatch from build log fixture', () async {
      final text = await File(
        'test/fixtures/build_logs/kotlin_gradle_mismatch.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('android.kotlin-mismatch'));
    });

    test('Detects AndroidManifest merge conflict', () async {
      final text = await File(
        'test/fixtures/build_logs/manifest_merge_error.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(
        issues.map((i) => i.id),
        contains('android.manifest-merger-failure'),
      );
      final issue = issues.firstWhere(
        (i) => i.id == 'android.manifest-merger-failure',
      );
      expect(issue.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Detects Swift compiler error in iOS build log', () async {
      final text = await File(
        'test/fixtures/build_logs/swift_compile_error.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('ios.swift-compiler-error'));
    });

    test('Detects missing Android SDK components', () async {
      final text = await File(
        'test/fixtures/build_logs/android_sdk_missing.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('android.sdk-missing'));
    });

    test('Detects iOS code signing and CocoaPods issues', () async {
      final text = await File(
        'test/fixtures/build_logs/ios_signing.log',
      ).readAsString();
      final issues = BuildLogParser.parse(text);

      expect(issues.map((i) => i.id), contains('ios.signing-configuration'));
    });

    test('Classifies clean build output with empty issues list', () {
      final text = 'BUILD SUCCESSFUL in 12s\n27 actionable tasks: 27 executed';
      final result = BuildLogParser.parseDetailed(text);

      expect(result.issues, isEmpty);
      expect(result.classification.type, LogClassificationType.clean);
    });

    test('Classifies unknown failure log with explicit fallback issue', () {
      final text =
          'FAILURE: Build failed with an uncaught exception.\nExit code 1';
      final result = BuildLogParser.parseDetailed(text);

      expect(result.issues, hasLength(1));
      expect(result.issues.first.id, 'build.unknown-log-pattern');
      expect(
        result.issues.first.description,
        contains(
          'The log was analyzed successfully, but no supported diagnostic pattern matched. This does not prove the build is healthy.',
        ),
      );
      expect(result.classification.type, LogClassificationType.unknownPattern);
    });

    test('Strips ANSI color sequences and CI headers in normalizer', () {
      final raw =
          '\u001b[31m2026-09-12T10:00:00.000Z  ##[error]FAILURE: Build failed\u001b[0m';
      final normalized = BuildLogNormalizer.normalize(raw);

      expect(normalized.hasAnsi, isTrue);
      expect(normalized.hasCiHeader, isTrue);
      expect(normalized.cleanLog, contains('FAILURE: Build failed'));
      expect(normalized.cleanLog.contains('\u001b'), isFalse);
    });

    test(
      'Suppresses generic Gradle failure symptom when specific root cause matches',
      () {
        final text = '''
Manifest merger failed with multiple errors. See logs.
Execution failed for task ':app:processDebugMainManifest'.
''';
        final issues = BuildLogParser.parse(text);

        expect(
          issues.map((i) => i.id),
          contains('android.manifest-merger-failure'),
        );
        expect(
          issues.map((i) => i.id),
          isNot(contains('android.gradle-failure')),
        );
      },
    );

    test('Handles empty build log string gracefully', () {
      final result = BuildLogParser.parseDetailed('');
      expect(result.issues, isEmpty);
      expect(result.classification.type, LogClassificationType.empty);
    });
  });
}
