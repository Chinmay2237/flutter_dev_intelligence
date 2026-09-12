import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('Diagnostic Rules & Pipeline Unit Tests', () {
    test('Matches Pub Version Solving Rule correctly', () async {
      final logPath = 'test/fixtures/build_logs/pub_solver_failure.log';
      final file = File(logPath);
      expect(file.existsSync(), isTrue);

      final report = await BuildDoctor.analyzeLog(
        await file.readAsString(),
        sourceLabel: logPath,
      );
      expect(report.findings.isNotEmpty, isTrue);

      final finding = report.findings.first;
      expect(finding.id, equals('PUB_VERSION_SOLVING_FAILED'));
      expect(finding.category, equals(DiagnosticCategory.pubDependency));
      expect(finding.primaryStatus, equals(PrimaryStatus.primary));
      expect(finding.evidence.isNotEmpty, isTrue);
    });

    test(
      'Matches Gradle Dependency Resolution Rule and classifies task failure as cascading',
      () async {
        final logPath =
            'test/fixtures/build_logs/gradle_dependency_failure.log';
        final file = File(logPath);
        expect(file.existsSync(), isTrue);

        final report = await BuildDoctor.analyzeLog(
          await file.readAsString(),
          sourceLabel: logPath,
        );
        expect(report.findings.length, equals(2));

        final primary = report.primaryFindings;
        expect(primary.length, equals(1));
        expect(primary.first.id, equals('GRADLE_DEPENDENCY_RESOLUTION_FAILED'));
        expect(
          primary.first.category,
          equals(DiagnosticCategory.androidGradle),
        );

        final cascading = report.cascadingFindings;
        expect(cascading.length, equals(1));
        expect(cascading.first.id, equals('GRADLE_TASK_FAILED'));
      },
    );

    test('Matches Java AGP Incompatibility Rule', () async {
      final logPath = 'test/fixtures/build_logs/java_agp_incompatibility.log';
      final file = File(logPath);
      expect(file.existsSync(), isTrue);

      final report = await BuildDoctor.analyzeLog(
        await file.readAsString(),
        sourceLabel: logPath,
      );
      expect(report.findings.isNotEmpty, isTrue);
      expect(
        report.findings.any((f) => f.id == 'JAVA_AGP_INCOMPATIBILITY'),
        isTrue,
      );
    });

    test('Matches CocoaPods Failure Rule', () async {
      final logPath = 'test/fixtures/build_logs/cocoapods_failure.log';
      final file = File(logPath);
      expect(file.existsSync(), isTrue);

      final report = await BuildDoctor.analyzeLog(
        await file.readAsString(),
        sourceLabel: logPath,
      );
      expect(report.findings.isNotEmpty, isTrue);
      expect(
        report.findings.any((f) => f.id == 'COCOAPODS_RESOLUTION_FAILED'),
        isTrue,
      );
    });

    test(
      'Handles successful build log without false positive errors',
      () async {
        final logPath = 'test/fixtures/build_logs/successful_build.log';
        final file = File(logPath);
        expect(file.existsSync(), isTrue);

        final report = await BuildDoctor.analyzeLog(
          await file.readAsString(),
          sourceLabel: logPath,
        );
        expect(report.findings.isEmpty, isTrue);
        expect(report.primaryFindings.isEmpty, isTrue);
      },
    );
  });
}
