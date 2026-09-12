@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 8 CLI Sub-commands & Options Tests', () {
    const binPath = 'bin/flutter_dev_intelligence.dart';

    test('CLI --help prints command summary and exit code 0', () async {
      final process = await Process.run('dart', [binPath, '--help']);
      expect(process.exitCode, 0);
      expect(process.stdout, contains('Flutter Dev Intelligence'));
      expect(process.stdout, contains('doctor'));
      expect(process.stdout, contains('build-doctor'));
      expect(process.stdout, contains('ui-doctor'));
      expect(process.stdout, contains('performance'));
    });

    test('CLI --version prints package version', () async {
      final process = await Process.run('dart', [binPath, '--version']);
      expect(process.exitCode, 0);
      expect(
        process.stdout,
        contains('flutter_dev_intelligence $kPackageVersion'),
      );
    });

    test('CLI ui-doctor runs static UI analysis', () async {
      final process = await Process.run('dart', [
        binPath,
        'ui-doctor',
        '--project',
        '.',
        '--format',
        'json',
      ]);

      expect(process.exitCode, inInclusiveRange(0, 1));
      final json = jsonDecode(process.stdout as String) as Map<String, dynamic>;
      expect(json['projectName'], 'flutter_dev_intelligence');
      expect(json['analyzedSources'], isNotEmpty);
    });

    test(
      'CLI aliases (ui, build, perf) execute corresponding commands',
      () async {
        final uiProcess = await Process.run('dart', [
          binPath,
          'ui',
          '--project',
          '.',
          '--format',
          'json',
        ]);
        expect(uiProcess.exitCode, inInclusiveRange(0, 1));

        final buildProcess = await Process.run('dart', [
          binPath,
          'build',
          '--log',
          'test/fixtures/build_logs/duplicate_class.log',
          '--format',
          'json',
        ]);
        expect(buildProcess.exitCode, 1);

        final perfProcess = await Process.run('dart', [
          binPath,
          'perf',
          '--input',
          'test/fixtures/performance/devtools_trace.json',
          '--format',
          'json',
        ]);
        expect(perfProcess.exitCode, inInclusiveRange(0, 1));
      },
    );

    test(
      'CLI build-doctor processes build log file and detects issues',
      () async {
        final process = await Process.run('dart', [
          binPath,
          'build-doctor',
          '--log',
          'test/fixtures/build_logs/duplicate_class.log',
          '--format',
          'json',
        ]);

        expect(process.exitCode, 1);
        final json =
            jsonDecode(process.stdout as String) as Map<String, dynamic>;
        expect(json['issues'], isNotEmpty);
        expect(json['issues'].first['id'], 'android.duplicate-class');
      },
    );

    test('CLI build-doctor processes build log from stdin pipe', () async {
      final process = await Process.start('dart', [
        binPath,
        'build-doctor',
        '--stdin',
        '--format',
        'json',
      ]);

      final sampleLog = await File(
        'test/fixtures/build_logs/duplicate_class.log',
      ).readAsString();
      process.stdin.write(sampleLog);
      await process.stdin.close();

      final stdoutText = await process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      expect(exitCode, 1);
      final json = jsonDecode(stdoutText) as Map<String, dynamic>;
      expect(json['issues'], isNotEmpty);
      expect(json['analyzedSources'], contains('stdin'));
    });

    test('CLI writes report to output file via --output', () async {
      final tempDir = await Directory.systemTemp.createTemp('cli_out_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final reportPath = '${tempDir.path}/report.json';

      final process = await Process.run('dart', [
        binPath,
        'build-doctor',
        '--log',
        'test/fixtures/build_logs/duplicate_class.log',
        '--format',
        'json',
        '--output',
        reportPath,
      ]);

      expect(process.exitCode, 1);
      final outFile = File(reportPath);
      expect(await outFile.exists(), isTrue);
      final json =
          jsonDecode(await outFile.readAsString()) as Map<String, dynamic>;
      expect(json['issues'], isNotEmpty);
    });

    test('CLI respects --quiet mode and suppresses stdout', () async {
      final process = await Process.run('dart', [
        binPath,
        'build-doctor',
        '--log',
        'test/fixtures/build_logs/duplicate_class.log',
        '--quiet',
      ]);

      expect(process.stdout.toString(), isEmpty);
    });

    test(
      'CLI filters issues via --severity-threshold and --max-issues',
      () async {
        final process = await Process.run('dart', [
          binPath,
          'build-doctor',
          '--log',
          'test/fixtures/build_logs/duplicate_class.log',
          '--severity-threshold',
          'high',
          '--max-issues',
          '1',
          '--format',
          'json',
        ]);

        expect(process.exitCode, 1);
        final json =
            jsonDecode(process.stdout as String) as Map<String, dynamic>;
        final issues = json['issues'] as List;
        expect(issues.length, lessThanOrEqualTo(1));
      },
    );

    test('CLI rejects combining --stdin and --log', () async {
      final process = await Process.run('dart', [
        binPath,
        'build-doctor',
        '--stdin',
        '--log',
        'test/fixtures/build_logs/duplicate_class.log',
      ]);
      expect(process.exitCode, 2);
      expect(process.stderr, contains('Cannot combine --stdin and --log'));
    });

    test('CLI handles missing required options with exit code 2', () async {
      final process = await Process.run('dart', [binPath, 'build-doctor']);
      expect(process.exitCode, 2);
      expect(
        process.stderr,
        contains('Build Doctor requires --log <path> or --stdin'),
      );
    });

    test(
      'CLI handles non-existent paths with exit code 2 without raw stack trace',
      () async {
        final process = await Process.run('dart', [
          binPath,
          'doctor',
          '--project',
          '/nonexistent_path_xyz_123',
        ]);
        expect(process.exitCode, 2);
        expect(process.stderr, contains('Project directory not found'));
        expect(process.stderr.toString(), isNot(contains('#0      ')));
      },
    );

    test('CLI rejects --stdin for doctor and ui-doctor commands', () async {
      final docProcess = await Process.run('dart', [
        binPath,
        'doctor',
        '--stdin',
      ]);
      expect(docProcess.exitCode, 2);
      expect(
        docProcess.stderr,
        contains('The doctor command does not support --stdin'),
      );

      final uiProcess = await Process.run('dart', [
        binPath,
        'ui-doctor',
        '--stdin',
      ]);
      expect(uiProcess.exitCode, 2);
      expect(
        uiProcess.stderr,
        contains('The ui-doctor command does not support --stdin'),
      );
    });
  });

  group('Executable Configuration & Entry Point Tests', () {
    test(
      'Expected CLI entry-point file bin/flutter_dev_intelligence.dart exists',
      () async {
        final file = File('bin/flutter_dev_intelligence.dart');
        expect(
          await file.exists(),
          isTrue,
          reason: 'bin/flutter_dev_intelligence.dart must exist',
        );
      },
    );

    test('CLI entry point contains a valid main() function', () async {
      final file = File('bin/flutter_dev_intelligence.dart');
      final content = await file.readAsString();
      expect(
        content.contains('void main(') ||
            content.contains('Future<void> main('),
        isTrue,
        reason:
            'bin/flutter_dev_intelligence.dart must declare a main function',
      );
    });

    test('CLI entry point compiles without error', () async {
      final result = await Process.run('dart', [
        'analyze',
        'bin/flutter_dev_intelligence.dart',
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'Entry point file must analyze cleanly',
      );
    });

    test(
      'pubspec.yaml declares executables.flutter_dev_intelligence',
      () async {
        final pubspec = await File('pubspec.yaml').readAsString();
        expect(pubspec, contains('executables:'));
        expect(
          pubspec,
          contains('flutter_dev_intelligence: flutter_dev_intelligence'),
        );
      },
    );

    test('doctor command can be resolved via entry point', () async {
      final process = await Process.run('dart', [
        'bin/flutter_dev_intelligence.dart',
        'doctor',
        '--help',
      ]);
      expect(process.exitCode, 0);
      expect(process.stdout, contains('doctor'));
    });

    test(
      'invalid commands return a useful error and non-zero exit code',
      () async {
        final process = await Process.run('dart', [
          'bin/flutter_dev_intelligence.dart',
          '--unknown-flag-xyz',
        ]);
        expect(process.exitCode, 2);
        expect(
          process.stdout.toString() + process.stderr.toString(),
          contains('Flutter Dev Intelligence'),
        );
      },
    );
  });
}
