@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLI Command Routing & Analyzer Isolation Tests', () {
    const binPath = 'bin/flutter_dev_intelligence.dart';

    test(
      'doctor command executes DoctorRunner and does not run UI AST analysis',
      () async {
        final process = await Process.run('dart', [
          binPath,
          'doctor',
          '--project',
          '.',
          '--format',
          'json',
        ]);

        expect(process.exitCode, inInclusiveRange(0, 1));
        final json =
            jsonDecode(process.stdout as String) as Map<String, dynamic>;
        final analysis = json['analysis'] as Map<String, dynamic>;

        expect(analysis['command'], 'doctor');
        expect(analysis['analyzer'], 'DoctorRunner');
        expect(json['analyzedSources'], isNot(contains('static UI')));
      },
    );

    test('ui-doctor command executes UiAstAnalyzer on project lib', () async {
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
      final analysis = json['analysis'] as Map<String, dynamic>;

      expect(analysis['command'], 'ui-doctor');
      expect(analysis['analyzer'], 'UiAstAnalyzer');
      expect(analysis['rulesExecuted'], 17);
    });

    test(
      'ui-doctor command supports single file analysis via --file',
      () async {
        final process = await Process.run('dart', [
          binPath,
          'ui-doctor',
          '--file=test/fixtures/ui/unconstrained_scrollable.dart',
          '--format=json',
        ]);

        expect(process.exitCode, inInclusiveRange(0, 1));
        final json =
            jsonDecode(process.stdout as String) as Map<String, dynamic>;
        final analysis = json['analysis'] as Map<String, dynamic>;

        expect(analysis['command'], 'ui-doctor');
        expect(analysis['analyzer'], 'UiAstAnalyzer');
        expect(json['filesAnalyzed'], 1);
        expect(
          json['analyzedSources'],
          contains('test/fixtures/ui/unconstrained_scrollable.dart'),
        );
      },
    );

    test(
      'build-doctor requires --log or --stdin and returns error when missing',
      () async {
        final process = await Process.run('dart', [binPath, 'build-doctor']);

        expect(process.exitCode, 2);
        expect(
          process.stderr,
          contains('Build Doctor requires --log <path> or --stdin'),
        );
      },
    );

    test('build-doctor parses build log input via --log', () async {
      final process = await Process.run('dart', [
        binPath,
        'build-doctor',
        '--log=test/fixtures/build_logs/duplicate_class.log',
        '--format=json',
      ]);

      expect(process.exitCode, 1);
      final json = jsonDecode(process.stdout as String) as Map<String, dynamic>;
      final analysis = json['analysis'] as Map<String, dynamic>;

      expect(analysis['command'], 'build-doctor');
      expect(analysis['analyzer'], 'BuildLogParser');
      expect(analysis['rulesExecuted'], 41);
      expect(json['issues'], isNotEmpty);
    });

    test(
      'performance command requires performance input and does not fall back to doctor',
      () async {
        final process = await Process.run('dart', [binPath, 'performance']);

        expect(process.exitCode, 2);
        expect(process.stderr, contains('Performance doctor requires --input'));
        expect(
          process.stderr,
          contains('No performance trace data was supplied'),
        );
      },
    );

    test(
      'performance command parses trace file via --trace or --input',
      () async {
        final process = await Process.run('dart', [
          binPath,
          'performance',
          '--trace=test/fixtures/performance/devtools_trace.json',
          '--format=json',
        ]);

        expect(process.exitCode, inInclusiveRange(0, 1));
        final json =
            jsonDecode(process.stdout as String) as Map<String, dynamic>;
        final analysis = json['analysis'] as Map<String, dynamic>;

        expect(analysis['command'], 'performance');
        expect(analysis['analyzer'], 'PerformanceInputParser');
        expect(analysis['rulesExecuted'], 5);
      },
    );

    test('CLI command aliases route to their intended handlers', () async {
      final docAlias = await Process.run('dart', [
        binPath,
        'doc',
        '--format=json',
      ]);
      expect(docAlias.exitCode, inInclusiveRange(0, 1));
      final docJson =
          jsonDecode(docAlias.stdout as String) as Map<String, dynamic>;
      expect(docJson['analysis']['command'], 'doctor');

      final uiAlias = await Process.run('dart', [
        binPath,
        'ui',
        '--project=.',
        '--format=json',
      ]);
      expect(uiAlias.exitCode, inInclusiveRange(0, 1));
      final uiJson =
          jsonDecode(uiAlias.stdout as String) as Map<String, dynamic>;
      expect(uiJson['analysis']['command'], 'ui-doctor');

      final perfAlias = await Process.run('dart', [
        binPath,
        'perf-investigator',
        '--trace=test/fixtures/performance/devtools_trace.json',
        '--format=json',
      ]);
      expect(perfAlias.exitCode, inInclusiveRange(0, 1));
      final perfJson =
          jsonDecode(perfAlias.stdout as String) as Map<String, dynamic>;
      expect(perfJson['analysis']['command'], 'performance');
    });

    test('unknown command produces explicit error and exit code 2', () async {
      final process = await Process.run('dart', [binPath, 'nonexistent-cmd']);

      expect(process.exitCode, 2);
      expect(
        process.stderr,
        contains("Error: Unknown command 'nonexistent-cmd'"),
      );
    });
  });
}
