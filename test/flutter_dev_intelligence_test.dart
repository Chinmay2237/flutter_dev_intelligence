@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() {
  group('DevIntelligenceConfig', () {
    test('creates valid configuration with sensible defaults', () {
      const config = DevIntelligenceConfig();

      expect(config.enablePerformance, isTrue);
      expect(config.enableUiDoctor, isTrue);
      expect(config.enableBuildDoctor, isFalse);
      expect(config.debugOnly, isTrue);
      expect(config.maxEvents, greaterThan(0));
    });

    test('rejects invalid sample rate', () {
      expect(
        () => DevIntelligenceConfig(sampleRate: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('DiagnosticIssue', () {
    test('serializes to JSON and round-trips', () {
      final issue = DiagnosticIssue(
        id: 'gradle_conflict',
        category: DiagnosticCategory.build,
        severity: DiagnosticSeverity.high,
        title: 'Gradle compatibility warning',
        description: 'The project is using an incompatible Gradle version.',
        evidence: [
          EvidenceReference(
            type: EvidenceType.log,
            label: 'build.log',
            value: '/tmp/build.log',
          ),
        ],
        suggestions: [
          const FixSuggestion(
            action: 'Check Android Gradle Plugin compatibility',
            details:
                'Verify the Kotlin and AGP versions match the installed SDK.',
          ),
        ],
      );

      final json = issue.toJson();
      final decoded = DiagnosticIssue.fromJson(json);

      expect(decoded.id, issue.id);
      expect(decoded.category, issue.category);
      expect(decoded.severity, issue.severity);
      expect(
        decoded.suggestions.first.action,
        'Check Android Gradle Plugin compatibility',
      );
    });
  });

  group('DiagnosticReportRenderer', () {
    test('keeps terminal, JSON, and Markdown state aligned', () {
      final report = DiagnosticReport(
        id: 'report',
        createdAt: DateTime.utc(2026, 1, 1),
        projectName: 'demo',
        warnings: const ['lockfile skipped'],
        skippedAnalyses: const ['build log'],
        unavailableAnalyses: const ['AI provider'],
        limitations: const ['runtime-only checks were not measured'],
      );

      final terminal = DiagnosticReportRenderer.renderTerminal(report);
      final json =
          jsonDecode(DiagnosticReportRenderer.renderJson(report))
              as Map<String, dynamic>;
      final markdown = DiagnosticReportRenderer.renderMarkdown(report);

      expect(terminal, contains('Skipped checks: build log'));
      expect(terminal, contains('Unavailable: AI provider'));
      expect(json['severityCounts'], isA<Map<String, dynamic>>());
      expect(markdown, contains('## Limitations'));
      expect(markdown, contains('## Skipped Analyses'));
      expect(markdown, contains('## Unavailable Analyses'));
    });
  });

  group('PerformanceInvestigator', () {
    test('tracks traces and computes percentiles', () {
      final performance = PerformanceInvestigator();
      performance.startSession('session-1');
      performance.startTrace('load_products');
      performance.endTrace('load_products', durationMs: 120);
      performance.startTrace('render_products');
      performance.endTrace('render_products', durationMs: 60);
      performance.mark('products_rendered');

      final report = performance.generateReport();
      expect(report.metrics['trace_count'], 2);
      expect(report.metrics['slowest_trace_ms'], greaterThanOrEqualTo(120));
      expect(report.issues, isEmpty);
    });

    test('frame timing collector reports an empty session honestly', () {
      final collector = FrameTimingCollector(maxSamples: 2);

      final report = collector.generateReport();

      expect(report.metrics['frame_count'], 0);
      expect(report.metrics['slow_frame_count'], 0);
      expect(
        report.limitations,
        contains('No Flutter frame timings were collected.'),
      );
      collector.stop();
      collector.reset();
    });

    test('frame timing summary calculates percentiles and slow frames', () {
      final summary = FrameTimingSummary.fromDurations(
        buildMs: const [2, 4, 8, 12],
        rasterMs: const [2, 4, 8, 12],
      );

      expect(summary.frameCount, 4);
      expect(summary.slowFrameCount, 1);
      expect(summary.p50FrameMs, 8);
      expect(summary.p90FrameMs, 24);
      expect(summary.p99FrameMs, 24);
    });
  });

  group('SecretRedactor', () {
    test('redacts secrets from text', () {
      final redacted = SecretRedactor.redact(
        'token=abc123 API_KEY=secret-value Authorization: Bearer abc123',
      );

      expect(redacted, contains('[REDACTED]'));
      expect(redacted, isNot(contains('secret-value')));
      expect(redacted, isNot(contains('abc123')));
    });
  });

  group('FlutterProjectScanner', () {
    test('detects a Flutter project structure', () async {
      final dir = await Directory.systemTemp.createTemp('fdi_scan_');
      await File('${dir.path}/pubspec.yaml').writeAsString('''
name: demo_app

description: demo
version: 1.0.0

environment:
  sdk: ^3.11.0

flutter:
  uses-material-design: true
''');
      await Directory('${dir.path}/lib').create();
      await Directory('${dir.path}/android').create();

      final result = await FlutterProjectScanner.scan(dir.path);

      expect(result.exists, isTrue);
      expect(result.isFlutterProject, isTrue);
      expect(result.hasPubspec, isTrue);
      expect(result.platformFolders, contains('android'));
      await dir.delete(recursive: true);
    });
  });

  group('PubspecAnalyzer', () {
    test('reads dependency and sdk constraints from a valid pubspec', () async {
      final dir = await Directory.systemTemp.createTemp('fdi_pubspec_');
      await File('${dir.path}/pubspec.yaml').writeAsString('''
name: demo_app
version: 1.0.0

description: demo

environment:
  sdk: ^3.11.0
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.0

flutter:
  uses-material-design: true
''');

      final result = await PubspecAnalyzer.analyze(dir.path);

      expect(result.packageName, 'demo_app');
      expect(result.isFlutterProject, isTrue);
      expect(result.dependencies, contains('cupertino_icons'));
      expect(
        result.sdkConstraints.any((entry) => entry.contains('sdk')),
        isTrue,
      );
      await dir.delete(recursive: true);
    });
  });

  group('PubspecLockAnalyzer', () {
    test('reads package counts and source types from a lock file', () async {
      final dir = await Directory.systemTemp.createTemp('fdi_lock_');
      await File('${dir.path}/pubspec.lock').writeAsString('''
sdks:
  dart: "3.11.0"

packages:
  flutter:
    dependency: sdk
    source: sdk
  cupertino_icons:
    dependency: transitive
    source: hosted
    version: "1.0.0"
  local_package:
    dependency: "direct main"
    source: path
    version: "0.0.1"
  my_plugin:
    dependency: "direct main"
    source: git
    version: "1.2.3"
''');

      final result = await PubspecLockAnalyzer.analyze(dir.path);

      expect(result.exists, isTrue);
      expect(result.packageCount, greaterThanOrEqualTo(4));
      expect(result.hostedPackageCount, greaterThanOrEqualTo(1));
      expect(result.pathPackageCount, greaterThanOrEqualTo(1));
      expect(result.gitPackageCount, greaterThanOrEqualTo(1));
      expect(result.packageVersions['cupertino_icons'], '1.0.0');
      expect(result.packageSources['my_plugin'], 'git');
      expect(result.dependencyKinds['my_plugin'], 'direct main');
      expect(result.malformed, isFalse);
      await dir.delete(recursive: true);
    });

    test('reports declared dependencies missing from the lock file', () async {
      final dir = await Directory.systemTemp.createTemp('fdi_lock_mismatch_');
      await File('${dir.path}/pubspec.lock').writeAsString('''
packages:
  existing:
    dependency: "direct main"
    source: hosted
    version: "1.0.0"
''');

      final result = await PubspecLockAnalyzer.analyze(
        dir.path,
        expectedPackages: const ['existing', 'missing_package'],
      );

      expect(result.missingExpectedPackages, contains('missing_package'));
      expect(result.warnings.single, contains('missing_package'));
      await dir.delete(recursive: true);
    });

    test('marks empty and unsupported lockfiles as malformed', () async {
      final dir = await Directory.systemTemp.createTemp('fdi_lock_invalid_');
      await File('${dir.path}/pubspec.lock').writeAsString('''
packages:
  broken:
    source: workspace
''');

      final result = await PubspecLockAnalyzer.analyze(dir.path);

      expect(result.malformed, isTrue);
      expect(
        result.warnings,
        contains(contains('Unsupported lockfile source')),
      );
      await dir.delete(recursive: true);
    });
  });

  group('BuildLogParser', () {
    test(
      'detects Kotlin/Gradle compatibility and duplicate class issues',
      () async {
        final log = '''
        FAILURE: Build failed with an exception.
        * What went wrong:
        The Android Gradle Plugin was compiled with Kotlin 1.9.0 and the project uses Kotlin 1.8.22
        > Execution failed for task ':app:compileDebugKotlin'.
        Duplicate class found in modules app and lib
      ''';

        final issues = BuildLogParser.parse(log);

        expect(issues, isNotEmpty);
        expect(issues.any((issue) => issue.title.contains('Kotlin')), isTrue);
        expect(
          issues.any((issue) => issue.title.contains('Duplicate class')),
          isTrue,
        );
      },
    );

    test('detects platform and dependency resolution failures', () {
      final issues = BuildLogParser.parse('''
        Android SDK location not found.
        Unsupported class file major version 65.
        Failed to resolve: com.example:missing:1.0
        No profiles for com.example.app were found.
      ''');

      expect(issues.map((issue) => issue.id), contains('android.sdk-missing'));
      expect(
        issues.map((issue) => issue.id),
        contains('android.java-runtime-mismatch'),
      );
      expect(
        issues.map((issue) => issue.id),
        contains('android.dependency-resolution-failure'),
      );
      expect(
        issues.map((issue) => issue.id),
        contains('ios.signing-configuration'),
      );
    });
  });

  group('CLI', () {
    test('prints help and version output', () async {
      final help = await Process.run('dart', [
        'run',
        'bin/flutter_dev_intelligence.dart',
        '--help',
      ], runInShell: true);
      final version = await Process.run('dart', [
        'run',
        'bin/flutter_dev_intelligence.dart',
        '--version',
      ], runInShell: true);

      expect(help.exitCode, 0);
      expect(version.exitCode, 0);
      expect(help.stdout.toString(), contains('Usage:'));
      expect(version.stdout.toString(), contains('flutter_dev_intelligence'));
    });

    test('diagnostic command can scan a real temp project', () async {
      final dir = await Directory.systemTemp.createTemp('fdi_cli_');
      await File('${dir.path}/pubspec.yaml').writeAsString('''
name: demo_app
description: demo
version: 1.0.0

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
''');

      final result = await Process.run('dart', [
        'run',
        'bin/flutter_dev_intelligence.dart',
        'doctor',
        dir.path,
      ], runInShell: true);

      expect(result.exitCode, 0);
      expect(result.stdout.toString(), contains('demo_app'));
      await dir.delete(recursive: true);
    });

    test(
      'doctor supports JSON, Markdown, build logs, and output files',
      () async {
        final dir = await Directory.systemTemp.createTemp('fdi_cli_formats_');
        await File('${dir.path}/pubspec.yaml').writeAsString('''
name: format_app
description: demo
version: 1.0.0
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''');
        final log = File('${dir.path}/build.log');
        await log.writeAsString('Duplicate class found in modules app and lib');
        final output = '${dir.path}/report.json';
        final nestedOutput = '${dir.path}/nested/report.json';

        final jsonResult = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'doctor',
          '--project',
          dir.path,
          '--format',
          'json',
        ], runInShell: true);
        final decoded =
            jsonDecode(jsonResult.stdout.toString()) as Map<String, dynamic>;
        expect(decoded['toolName'], 'flutter_dev_intelligence');
        expect(decoded['projectPath'], dir.path);

        final markdownResult = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'doctor',
          '--project',
          dir.path,
          '--format',
          'markdown',
        ], runInShell: true);
        expect(
          markdownResult.stdout.toString(),
          contains('# Flutter Dev Intelligence Report'),
        );
        expect(markdownResult.stdout.toString(), contains('format_app'));

        final logResult = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'doctor',
          '--project',
          dir.path,
          '--log',
          log.path,
        ], runInShell: true);
        expect(logResult.exitCode, 1);
        expect(
          logResult.stdout.toString(),
          contains('Duplicate class detected'),
        );

        final outputResult = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'doctor',
          '--project',
          dir.path,
          '--format',
          'json',
          '--output',
          output,
        ], runInShell: true);
        expect(outputResult.exitCode, 0);
        expect(
          jsonDecode(await File(output).readAsString()),
          isA<Map<String, dynamic>>(),
        );

        final nestedOutputResult = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'doctor',
          '--project',
          dir.path,
          '--format',
          'json',
          '--output',
          nestedOutput,
        ], runInShell: true);
        expect(nestedOutputResult.exitCode, 0);
        expect(await File(nestedOutput).exists(), isTrue);
        await dir.delete(recursive: true);
      },
    );

    test(
      'doctor rejects invalid paths and formats without a stack trace',
      () async {
        final invalidPath = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'doctor',
          '--project',
          '/path/that/does/not/exist',
        ], runInShell: true);
        expect(invalidPath.exitCode, 2);
        expect(
          invalidPath.stderr.toString(),
          contains('Project directory not found'),
        );

        final invalidFormat = await Process.run('dart', [
          'run',
          'bin/flutter_dev_intelligence.dart',
          'doctor',
          '--format',
          'xml',
        ], runInShell: true);
        expect(invalidFormat.exitCode, 2);
        expect(
          invalidFormat.stderr.toString(),
          contains('Unsupported output format'),
        );
        expect(invalidFormat.stderr.toString(), isNot(contains('StackTrace')));
      },
    );
  });

  group('DoctorRunner', () {
    test('includes static UI evidence from a project lib directory', () async {
      final dir = await Directory.systemTemp.createTemp('fdi_runner_ui_');
      await File('${dir.path}/pubspec.yaml').writeAsString('''
name: runner_app
version: 1.0.0
environment:
  sdk: ^3.11.0
''');
      await Directory('${dir.path}/lib').create();
      await File('${dir.path}/lib/main.dart').writeAsString('''
import 'package:flutter/widgets.dart';

Widget buildWidget() => ListView(
  children: <Widget>[
    GridView.builder(
      shrinkWrap: true,
      itemCount: 2,
      itemBuilder: (context, index) => const Text('item'),
    ),
  ],
);
''');

      final report = await DoctorRunner.run(
        DoctorOptions(projectPath: dir.path, includeUiDoctor: true),
      );

      expect(report.analyzedSources, contains('static UI'));
      expect(
        report.issues.map((issue) => issue.id),
        contains('ui.nested-scrollable'),
      );
      await dir.delete(recursive: true);
    });
  });

  group('BuildDoctor', () {
    test('detects dependency and gradle conflicts from logs', () {
      final issue = BuildDoctor.detectIssueFromLog(
        'FAILURE: Build failed with an exception.\n'
        'The Android Gradle Plugin was compiled with Kotlin 1.9.0 and the project uses Kotlin 1.8.22',
      );

      expect(issue, isNotNull);
      expect(issue.category, DiagnosticCategory.build);
      expect(issue.severity, DiagnosticSeverity.high);
      expect(issue.title, contains('Kotlin'));
    });
  });

  group('UiDoctor', () {
    test('flags viewport overflow risk for narrow layouts', () {
      final report = UiDoctor.inspectViewport(
        width: 320,
        height: 640,
        contentWidth: 420,
        contentHeight: 1200,
      );

      expect(report.issues, isNotEmpty);
      expect(report.issues.first.title, contains('overflow'));
    });
  });

  group('UiAstAnalyzer', () {
    test('reports conservative source heuristics with locations', () {
      final result = UiAstAnalyzer.analyzeSource('''
import 'package:flutter/widgets.dart';

Widget buildWidget() => ListView(
  children: <Widget>[
    GridView.builder(
      shrinkWrap: true,
      itemCount: 2,
      itemBuilder: (context, index) => const Text('item'),
    ),
    const SizedBox(width: 1200),
  ],
);
''', filePath: 'nested.dart');

      expect(result.parseErrors, isEmpty);
      expect(
        result.issues.map((issue) => issue.id),
        contains('ui.nested-scrollable'),
      );
      expect(
        result.issues.map((issue) => issue.id),
        contains('ui.nested-shrink-wrap'),
      );
      expect(
        result.issues.map((issue) => issue.id),
        contains('ui.oversized-dimension'),
      );
      expect(
        result.issues.every((issue) => issue.source.startsWith('static')),
        isTrue,
      );
      expect(result.issues.every((issue) => issue.line != null), isTrue);
    });

    test('does not report a simple constrained scrollable', () {
      final result = UiAstAnalyzer.analyzeSource('''
import 'package:flutter/widgets.dart';

Widget buildWidget() => const SizedBox(
  width: 320,
  height: 240,
  child: ListView(),
);
''');

      expect(result.parseErrors, isEmpty);
      expect(result.issues, isEmpty);
    });
  });
}
