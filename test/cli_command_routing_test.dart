import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('CLI Executable Command Routing & Exit Code Contract', () {
    test(
      'Exit Code 0: Executable prints help when --help flag passed',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          '--help',
        ]);
        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('Flutter Dev Intelligence'));
        expect(result.stdout.toString(), contains('build-doctor'));
      },
    );

    test(
      'Exit Code 0: Executable prints version when --version flag passed',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          '--version',
        ]);
        expect(result.exitCode, equals(0));
        expect(
          result.stdout.toString(),
          contains('flutter_dev_intelligence $kPackageVersion'),
        );
      },
    );

    test(
      'Exit Code 0: Executable returns exit code 0 on clean log fixture',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'build-doctor',
          '--log=test/fixtures/build_logs/successful_build.log',
        ]);
        expect(result.exitCode, equals(0));
        expect(
          result.stdout.toString(),
          contains('No build errors or diagnostic issues detected'),
        );
      },
    );

    test(
      'Exit Code 1: Executable returns exit code 1 when error finding detected',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'build-doctor',
          '--log=test/fixtures/build_logs/gradle_dependency_failure.log',
        ]);
        expect(result.exitCode, equals(1));
        expect(
          result.stdout.toString(),
          contains('Flutter Dev Intelligence Diagnostics'),
        );
        expect(
          result.stdout.toString(),
          contains('GRADLE_DEPENDENCY_RESOLUTION_FAILED'),
        );
      },
    );

    test(
      'Exit Code 1: Executable outputs JSON format when --format=json passed',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'build-doctor',
          '--log=test/fixtures/build_logs/pub_solver_failure.log',
          '--format=json',
        ]);
        expect(result.exitCode, equals(1));
        expect(result.stdout.toString(), contains('"schemaVersion": "1.0"'));
        expect(
          result.stdout.toString(),
          contains('"PUB_VERSION_SOLVING_FAILED"'),
        );
      },
    );

    test(
      'Exit Code 1: Executable outputs Markdown format when --format=markdown passed',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'build-doctor',
          '--log=test/fixtures/build_logs/pub_solver_failure.log',
          '--format=markdown',
        ]);
        expect(result.exitCode, equals(1));
        expect(
          result.stdout.toString(),
          contains('# Flutter Dev Intelligence Diagnostic Report'),
        );
        expect(
          result.stdout.toString(),
          contains('## Primary Suspected Issues'),
        );
      },
    );

    test(
      'Exit Code 2: Executable returns exit code 2 when non-existent log file passed',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'build-doctor',
          '--log=non_existent_file.log',
        ]);
        expect(result.exitCode, equals(2));
        expect(result.stderr.toString(), contains('Build log file not found'));
      },
    );

    test(
      'Exit Code 2: Executable returns exit code 2 when unsupported format passed',
      () async {
        final result = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'build-doctor',
          '--log=test/fixtures/build_logs/successful_build.log',
          '--format=html',
        ]);
        expect(result.exitCode, equals(2));
        expect(result.stderr.toString(), contains('Unsupported output format'));
      },
    );

    test('Executable writes report to file when --output specified', () async {
      final outputPath = '/tmp/test_report.json';
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_dev_intelligence.dart',
        'build-doctor',
        '--log=test/fixtures/build_logs/pub_solver_failure.log',
        '--format=json',
        '--output=$outputPath',
      ]);

      expect(result.exitCode, equals(1));
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content, contains('"PUB_VERSION_SOLVING_FAILED"'));
      outputFile.deleteSync();
    });
  });
}
