import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('CLI Options & Flags Tests', () {
    test('Handles --ascii flag without throwing', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_dev_intelligence.dart',
        'build-doctor',
        '--log=test/fixtures/build_logs/gradle_dependency_failure.log',
        '--ascii',
      ]);

      expect(result.exitCode, equals(1));
      expect(
        result.stdout.toString(),
        contains('Flutter Dev Intelligence Diagnostics'),
      );
    });

    test('Handles --color=never flag without ANSI escape sequences', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_dev_intelligence.dart',
        'build-doctor',
        '--log=test/fixtures/build_logs/pub_solver_failure.log',
        '--color=never',
      ]);

      expect(result.exitCode, equals(1));
      expect(result.stdout.toString(), isNot(contains('\x1B[')));
    });
  });
}
