@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() {
  group('Phase 9 — Diagnostic Output Contracts & Schema Standardization', () {
    test(
      'JSON output contains versioned schema, tool, analysis, and summary blocks',
      () {
        final report = DiagnosticReport(
          id: 'ui_report_1',
          createdAt: DateTime.utc(2026, 9, 12, 12, 0, 0),
          projectName: 'demo_app',
          projectPath: '/path/to/demo',
          durationMs: 150,
          filesAnalyzed: 25,
          rulesExecuted: 17,
          issues: [
            DiagnosticIssue(
              id: 'ui.nested-scrollable',
              category: DiagnosticCategory.layout,
              severity: DiagnosticSeverity.high,
              title: 'Nested scrollables with shrinkWrap',
              description: 'ListView contains shrinkWrapped GridView.',
            ),
            DiagnosticIssue(
              id: 'ui.missing-tooltip',
              category: DiagnosticCategory.accessibility,
              severity: DiagnosticSeverity.info,
              title: 'IconButton missing tooltip',
              description: 'IconButton without tooltip.',
            ),
          ],
        );

        final jsonStr = DiagnosticReportRenderer.renderJson(report);
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

        expect(decoded['schemaVersion'], '1.0');
        expect(decoded['tool']['name'], 'flutter_dev_intelligence');
        expect(decoded['tool']['version'], kPackageVersion);

        final analysis = decoded['analysis'] as Map<String, dynamic>;
        expect(analysis['status'], 'actionable');
        expect(analysis['durationMs'], 150);
        expect(analysis['filesAnalyzed'], 25);
        expect(analysis['rulesExecuted'], 17);

        final summary = decoded['summary'] as Map<String, dynamic>;
        expect(summary['high'], 1);
        expect(summary['info'], 1);
        expect(summary['actionable'], 1);
        expect(summary['total'], 2);
      },
    );

    test('Zero ANSI codes in JSON and Markdown output', () {
      final report = DiagnosticReport(
        id: 'ansi_check',
        createdAt: DateTime.now(),
        projectName: 'ansi_app',
        issues: [
          DiagnosticIssue(
            id: 'build.gradle-conflict',
            category: DiagnosticCategory.build,
            severity: DiagnosticSeverity.critical,
            title: '\x1B[31mCritical Gradle Error\x1B[0m',
            description: '\x1B[1mStacktrace error\x1B[0m',
          ),
        ],
      );

      final jsonOutput = DiagnosticReportRenderer.renderJson(report);
      final mdOutput = DiagnosticReportRenderer.renderMarkdown(report);

      expect(DiagnosticReportRenderer.ansiRegex.hasMatch(jsonOutput), isFalse);
      expect(DiagnosticReportRenderer.ansiRegex.hasMatch(mdOutput), isFalse);
    });

    test(
      'DiagnosticReport.fromJson guarantees backward compatibility with 1.0.0 and legacy schemas',
      () {
        final legacyJson = {
          'id': 'legacy_1',
          'createdAt': '2026-09-12T00:00:00.000Z',
          'projectName': 'legacy_app',
          'toolName': 'flutter_dev_intelligence',
          'toolVersion': '0.1.0',
          'durationMs': 200,
          'issues': [],
        };

        final report = DiagnosticReport.fromJson(legacyJson);
        expect(report.projectName, 'legacy_app');
        expect(report.toolName, 'flutter_dev_intelligence');
        expect(report.toolVersion, '0.1.0');
        expect(report.durationMs, 200);
      },
    );

    test(
      'Markdown renderer formats INFO findings cleanly without treating them as errors',
      () {
        final report = DiagnosticReport(
          id: 'md_info_test',
          createdAt: DateTime.now(),
          projectName: 'info_app',
          issues: [
            DiagnosticIssue(
              id: 'perf.const-widget',
              category: DiagnosticCategory.performance,
              severity: DiagnosticSeverity.info,
              title: 'Suggest const prefix for immutable widget',
              description: 'Widget can be instantiated with const.',
            ),
          ],
        );

        final md = DiagnosticReportRenderer.renderMarkdown(report);

        expect(
          md,
          contains('### [INFO] Suggest const prefix for immutable widget'),
        );
        expect(md, contains('- **Info:** 1'));
        expect(md, isNot(contains('- **High:** 1')));
      },
    );

    test(
      'Cross-engine schema consistency for BuildDoctor, UiDoctor, and Performance reports',
      () {
        final buildIssue = BuildDoctor.detectIssueFromLog(
          'The Android Gradle Plugin was compiled with Kotlin 1.9.0 and the project uses Kotlin 1.8.22',
        );
        final buildReport = DiagnosticReport(
          id: 'build_engine_1',
          createdAt: DateTime.now(),
          projectName: 'build_app',
          issues: [buildIssue],
        );

        final uiResult = UiAstAnalyzer.analyzeSource(
          'import "package:flutter/widgets.dart"; Widget build() => ListView(children: [GridView.builder(shrinkWrap: true, itemCount: 2, itemBuilder: (c, i) => Text("hi"))]);',
        );
        final uiReport = DiagnosticReport(
          id: 'ui_engine_1',
          createdAt: DateTime.now(),
          projectName: 'ui_app',
          issues: uiResult.issues,
        );

        final perfResult = PerformanceInputParser.parse({
          'frames': [10.0, 20.0, 30.0],
        });
        final perfReport = DiagnosticReport(
          id: 'perf_engine_1',
          createdAt: DateTime.now(),
          projectName: 'perf_app',
          issues: perfResult.issues,
          metrics: perfResult.summary?.toJson() ?? {},
        );

        for (final report in [buildReport, uiReport, perfReport]) {
          final jsonStr = DiagnosticReportRenderer.renderJson(report);
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          expect(decoded.containsKey('schemaVersion'), isTrue);
          expect(decoded.containsKey('tool'), isTrue);
          expect(decoded.containsKey('analysis'), isTrue);
          expect(decoded.containsKey('summary'), isTrue);
        }
      },
    );
  });
}
