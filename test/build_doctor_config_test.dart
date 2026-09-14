import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('BuildDoctorEngine & ProjectConfig Integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'build_doctor_config_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const sampleGradleErrorLog = '''
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:compileDebugJavaWithJavac'.
> Could not resolve all dependencies for configuration ':app:debugCompileClasspath'.
   > Could not find com.example:missing-library:1.0.0.
     Searched in the following locations:
       - https://repo.maven.apache.org/maven2/com/example/missing-library/1.0.0/missing-library-1.0.0.pom
BUILD FAILED in 5s
''';

    test(
      'BuildDoctorEngine detects findings when no rules are disabled',
      () async {
        final report = await BuildDoctorEngine.analyze(
          options: BuildDoctorEngineOptions(
            logContent: sampleGradleErrorLog,
            projectPath: tempDir.path,
          ),
        );

        final ruleIds = report.findings.map((f) => f.id).toSet();
        expect(ruleIds, contains('GRADLE_DEPENDENCY_RESOLUTION_FAILED'));
      },
    );

    test(
      'BuildDoctorEngine respects disabled_rules in ProjectConfig',
      () async {
        final configYaml = '''
version: 1
rules:
  disabled:
    - GRADLE_DEPENDENCY_RESOLUTION_FAILED
''';

        final config = ProjectConfig.parseYaml(configYaml).config;

        final report = await BuildDoctorEngine.analyze(
          options: BuildDoctorEngineOptions(
            logContent: sampleGradleErrorLog,
            projectPath: tempDir.path,
            config: config,
          ),
        );

        final ruleIds = report.findings.map((f) => f.id).toSet();
        expect(ruleIds, isNot(contains('GRADLE_DEPENDENCY_RESOLUTION_FAILED')));
      },
    );

    test('BuildDoctorEngine respects suppressions in ProjectConfig', () async {
      final configYaml = '''
version: 1
suppressions:
  - rule: "GRADLE_DEPENDENCY_RESOLUTION_FAILED"
    reason: "Suppressed for unit testing"
''';

      final config = ProjectConfig.parseYaml(configYaml).config;

      final report = await BuildDoctorEngine.analyze(
        options: BuildDoctorEngineOptions(
          logContent: sampleGradleErrorLog,
          projectPath: tempDir.path,
          config: config,
        ),
      );

      final ruleIds = report.findings.map((f) => f.id).toSet();
      expect(ruleIds, isNot(contains('GRADLE_DEPENDENCY_RESOLUTION_FAILED')));
    });
  });
}
