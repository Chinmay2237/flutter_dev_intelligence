import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 2 Lockfile Analyzer Tests', () {
    test('Analyzes hosted lockfile correctly', () async {
      final fixturePath = 'test/fixtures/lockfiles/hosted_lock.lock';
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);

      // Create a temporary dir with pubspec.lock copy
      final tempDir = await Directory.systemTemp.createTemp(
        'lock_test_hosted_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await file.copy('${tempDir.path}/pubspec.lock');

      final result = await PubspecLockAnalyzer.analyze(
        tempDir.path,
        expectedPackages: ['analyzer', 'yaml', 'missing_pkg'],
      );

      expect(result.exists, isTrue);
      expect(result.malformed, isFalse);
      expect(result.packageCount, 3);
      expect(result.hostedPackageCount, 3);
      expect(result.gitPackageCount, 0);
      expect(result.directMainCount, 1);
      expect(result.directDevCount, 1);
      expect(result.transitiveCount, 1);
      expect(result.packageVersions['analyzer'], '9.0.0');
      expect(result.packageVersions['yaml'], '3.1.2');
      expect(result.missingExpectedPackages, ['missing_pkg']);
      expect(
        result.warnings,
        contains(
          contains(
            'Dependencies declared in pubspec.yaml but absent from pubspec.lock',
          ),
        ),
      );
    });

    test('Analyzes Git, Path, and SDK lockfile sources correctly', () async {
      final fixturePath = 'test/fixtures/lockfiles/git_path_lock.lock';
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);

      final tempDir = await Directory.systemTemp.createTemp('lock_test_git_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await file.copy('${tempDir.path}/pubspec.lock');

      final result = await PubspecLockAnalyzer.analyze(tempDir.path);

      expect(result.exists, isTrue);
      expect(result.malformed, isFalse);
      expect(result.packageCount, 3);
      expect(result.gitPackageCount, 1);
      expect(result.pathPackageCount, 1);
      expect(result.sdkPackageCount, 1);
      expect(result.packageSources['my_git_package'], 'git');
      expect(result.packageSources['local_utils'], 'path');
      expect(result.packageSources['flutter'], 'sdk');
      expect(result.packageVersions['my_git_package'], '1.2.0');
    });

    test('Detects malformed lockfile syntax gracefully', () async {
      final fixturePath = 'test/fixtures/lockfiles/malformed.lock';
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);

      final tempDir = await Directory.systemTemp.createTemp(
        'lock_test_malformed_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await file.copy('${tempDir.path}/pubspec.lock');

      final result = await PubspecLockAnalyzer.analyze(tempDir.path);

      expect(result.exists, isTrue);
      expect(result.malformed, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.first,
        contains('Failed to parse pubspec.lock YAML'),
      );
    });

    test('Handles missing pubspec.lock gracefully', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lock_test_missing_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final result = await PubspecLockAnalyzer.analyze(tempDir.path);

      expect(result.exists, isFalse);
      expect(result.packageCount, 0);
      expect(result.warnings, contains('pubspec.lock is missing.'));
    });

    test('Handles empty pubspec.lock file gracefully', () async {
      final tempDir = await Directory.systemTemp.createTemp('lock_test_empty_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await File('${tempDir.path}/pubspec.lock').writeAsString('');

      final result = await PubspecLockAnalyzer.analyze(tempDir.path);

      expect(result.exists, isTrue);
      expect(result.malformed, isTrue);
      expect(result.warnings, contains('pubspec.lock is empty.'));
    });
  });
}
