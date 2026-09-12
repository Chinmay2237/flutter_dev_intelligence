import 'dart:io';

import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fdi_scale_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 11: Scale, Performance & Reliability Benchmarks', () {
    test(
      '1. Large Repository Source Discovery (1,000 files benchmark)',
      () async {
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);

        // Create 50 subdirectories with 20 files each = 1,000 files
        for (var d = 0; d < 50; d++) {
          final subDir = Directory('${libDir.path}/feature_$d');
          await subDir.create(recursive: true);
          for (var f = 0; f < 20; f++) {
            final file = File('${subDir.path}/widget_$f.dart');
            await file.writeAsString(
              'import "package:flutter/material.dart";\n'
              'class Widget${d}_$f extends StatelessWidget {\n'
              '  const Widget${d}_$f({super.key});\n'
              '  @override\n'
              '  Widget build(BuildContext context) => const Text("Widget ${d}_$f");\n'
              '}\n',
            );
          }
        }

        final stopwatch = Stopwatch()..start();
        final discoverer = const AstSourceDiscoverer();
        final result = await discoverer.discover(libDir.path);
        stopwatch.stop();

        expect(result.discoveredPaths.length, equals(1000));
        expect(result.skippedFiles, isEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Fast traversal

        // Verify stable sorting order
        final sortedPaths = List<String>.from(result.discoveredPaths)..sort();
        expect(result.discoveredPaths, equals(sortedPaths));
      },
    );

    test('2. Large Build Log Processing (10MB log with head/tail truncation)', () {
      final buffer = StringBuffer();
      // Write 2MB of preamble lines
      for (var i = 0; i < 40000; i++) {
        buffer.writeln(
          '\x1B[32m2026-09-12T10:00:00.000Z [ci] > Task :app:compileReleaseKotlin line $i\x1B[0m',
        );
      }

      // Write 2MB of middle stack trace lines
      for (var i = 0; i < 40000; i++) {
        buffer.writeln(
          '    at org.gradle.internal.runner.Execution.execute(Execution.java:$i)',
        );
      }

      // Insert Gradle failure pattern near tail
      buffer.writeln('FAILURE: Build failed with an exception.');
      buffer.writeln('* What went wrong:');
      buffer.writeln(
        'Execution failed for task \':app:compileReleaseKotlin\'.',
      );
      buffer.writeln(
        '> Duplicate class com.example.Foo found in modules foo-1.0.jar and foo-2.0.jar',
      );
      buffer.writeln('BUILD FAILED in 45s');

      final rawLog = buffer.toString();
      expect(rawLog.length, greaterThan(2 * 1024 * 1024)); // > 2MB

      final stopwatch = Stopwatch()..start();
      final parseResult = BuildLogParser.parseDetailed(
        rawLog,
        maxLogSizeBytes: 500 * 1024, // 500KB cap for testing truncation
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(
        parseResult.normalizedLog.cleanLog,
        contains('[... LOG TRUNCATED DUE TO SIZE LIMIT:'),
      );
      expect(parseResult.issues, isNotEmpty);
      expect(
        parseResult.issues.any((i) => i.id == 'android.duplicate-class'),
        isTrue,
      );
    });

    test('3. Large DevTools Trace Processing (50,000+ trace events cap)', () {
      final events = <Map<String, dynamic>>[];

      // Generate 60,000 trace events
      for (var i = 0; i < 60000; i++) {
        events.add({
          'name': i % 2 == 0 ? 'Build' : 'Raster',
          'cat': 'devtools',
          'ph': 'X',
          'ts': 1000000 + i * 1000,
          'dur': 8000, // 8ms
        });
      }

      final parseResult = PerformanceInputParser.parse({
        'traceEvents': events,
      }, maxTraceEvents: 50000);

      expect(parseResult.status, equals(PerformanceAnalysisStatus.valid));
      expect(parseResult.rawFrameCount, lessThanOrEqualTo(50000));
      expect(
        parseResult.warnings.any(
          (w) => w.contains('exceeded limit of 50000 events'),
        ),
        isTrue,
      );
    });

    test('4. Oversized File Skipping Safeguard (> 2MB file limit)', () async {
      final libDir = Directory('${tempDir.path}/lib');
      await libDir.create(recursive: true);

      // Create a small 1KB file
      final smallFile = File('${libDir.path}/normal.dart');
      await smallFile.writeAsString('class Normal {}');

      // Create an oversized 2.5MB file
      final largeFile = File('${libDir.path}/huge_generated.dart');
      final padding = '  // line of padding content\n' * 80000;
      final hugeContent = 'class Huge {\n$padding}\n';
      await largeFile.writeAsString(hugeContent);

      final discoverer = const AstSourceDiscoverer();
      final result = await discoverer.discover(
        libDir.path,
        config: const ProjectConfig(
          maxFileSizeBytes: 2 * 1024 * 1024,
        ), // 2MB limit
      );

      expect(result.discoveredPaths.length, equals(1));
      expect(result.discoveredPaths.first, endsWith('normal.dart'));
      expect(result.skippedFiles.length, equals(1));
      expect(result.skippedFiles.first, contains('exceeds 2.0MB limit'));
    });

    test(
      '5. Fault Isolation under Malformed Code & Engine Execution',
      () async {
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);

        // Malformed file with syntax error
        final brokenFile = File('${libDir.path}/broken.dart');
        await brokenFile.writeAsString(
          'class Broken { void foo() { if (true) {',
        );

        // Valid file
        final validFile = File('${libDir.path}/valid.dart');
        await validFile.writeAsString(
          'import "package:flutter/material.dart";\n'
          'class ValidWidget extends StatelessWidget {\n'
          '  const ValidWidget({super.key});\n'
          '  @override\n'
          '  Widget build(BuildContext context) => const Text("OK");\n'
          '}\n',
        );

        final results = await UiAstAnalyzer.analyzeDirectory(libDir.path);
        expect(results.length, equals(2));

        final brokenResult = results.firstWhere(
          (r) => r.filePath.endsWith('broken.dart'),
        );
        expect(
          brokenResult.parseErrors,
          isNotEmpty,
        ); // Gracefully captured parse error

        final validResult = results.firstWhere(
          (r) => r.filePath.endsWith('valid.dart'),
        );
        expect(validResult.parseErrors, isEmpty);
      },
    );

    test('6. Output Determinism & Stability under Scale', () {
      final log = '''
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:mergeReleaseResources'.
> AAPT2 error: Resource linking failed
''';

      final run1 = BuildLogParser.parseDetailed(log);
      final run2 = BuildLogParser.parseDetailed(log);

      expect(run1.issues.length, equals(run2.issues.length));
      expect(run1.issues.first.id, equals(run2.issues.first.id));
      expect(
        run1.issues.first.evidence.first.value,
        equals(run2.issues.first.evidence.first.value),
      );
    });
  });
}
