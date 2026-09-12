@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 8 CLI Sub-commands Tests', () {
    final binPath = 'bin/flutter_dev.dart';

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
      expect(process.stdout, contains('flutter_dev_intelligence 0.1.0-dev.2'));
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
        expect(json['issues'].first['id'], 'duplicate_class');
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

    test('CLI performance processes trace JSON metrics', () async {
      final tempDir = await Directory.systemTemp.createTemp('cli_perf_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final traceFile = File('${tempDir.path}/trace.json');
      await traceFile.writeAsString(
        jsonEncode({
          'frame_count': 10,
          'slow_frame_count': 3,
          'severe_jank_frame_count': 1,
          'average_build_ms': 12.5,
          'average_raster_ms': 10.0,
          'max_build_ms': 25.0,
          'max_raster_ms': 18.0,
          'worst_frame_ms': 43.0,
          'p50_frame_ms': 15.0,
          'p90_frame_ms': 35.0,
          'p99_frame_ms': 43.0,
          'frame_budget_ms': 16.67,
        }),
      );

      final process = await Process.run('dart', [
        binPath,
        'performance',
        '--input',
        traceFile.path,
        '--format',
        'json',
      ]);

      expect(process.exitCode, 1); // recommendations generated
      final json = jsonDecode(process.stdout as String) as Map<String, dynamic>;
      expect(json['metrics']['slow_frame_count'], 3);
      expect(json['issues'], isNotEmpty);
    });

    test('CLI performance processes trace JSON from stdin pipe', () async {
      final process = await Process.start('dart', [
        binPath,
        'performance',
        '--stdin',
        '--format',
        'json',
      ]);

      final traceJson = jsonEncode({
        'frame_count': 10,
        'slow_frame_count': 2,
        'average_build_ms': 15.0,
        'average_raster_ms': 12.0,
      });
      process.stdin.write(traceJson);
      await process.stdin.close();

      final stdoutText = await process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      expect(exitCode, 1);
      final json = jsonDecode(stdoutText) as Map<String, dynamic>;
      expect(json['metrics']['slow_frame_count'], 2);
    });

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

    test('CLI handles non-existent paths with exit code 2', () async {
      final process = await Process.run('dart', [
        binPath,
        'doctor',
        '--project',
        '/nonexistent_path_xyz_123',
      ]);
      expect(process.exitCode, 2);
      expect(process.stderr, contains('Project directory not found'));
    });

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
}
