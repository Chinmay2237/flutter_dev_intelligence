@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() {
  group('Phase 8 — CLI Golden & Renderer Tests', () {
    late DiagnosticReport sampleReport;

    setUp(() {
      sampleReport = DiagnosticReport(
        id: 'test_report_123',
        createdAt: DateTime.utc(2026, 9, 12, 12, 0, 0),
        projectName: 'demo_app',
        projectPath: '/path/to/demo_app',
        toolName: 'flutter_dev_intelligence',
        toolVersion: '1.0.0',
        durationMs: 184,
        filesAnalyzed: 42,
        rulesExecuted: 28,
        issues: [
          DiagnosticIssue(
            id: 'ui.nested-scrollable',
            category: DiagnosticCategory.layout,
            severity: DiagnosticSeverity.high,
            title: 'Nested scrollables with shrinkWrap detected',
            description:
                'ListView contains a child GridView with shrinkWrap enabled.',
            filePath: 'lib/widgets/my_list.dart',
            line: 42,
            confidence: 0.90,
            evidence: const [
              EvidenceReference(
                type: EvidenceType.sourceFile,
                label: 'parent',
                value: 'ListView',
              ),
              EvidenceReference(
                type: EvidenceType.sourceFile,
                label: 'child',
                value: 'GridView',
              ),
            ],
            suggestions: const [
              FixSuggestion(
                action:
                    'Replace inner GridView with SliverGrid inside CustomScrollView.',
                details:
                    'Using Slivers eliminates shrinkWrap calculation overhead.',
              ),
            ],
          ),
          DiagnosticIssue(
            id: 'ui.flex-outside-flex',
            category: DiagnosticCategory.layout,
            severity: DiagnosticSeverity.medium,
            title: 'Expanded widget used outside Row, Column, or Flex',
            description: 'Expanded widget is a direct child of Container.',
            filePath: 'lib/screens/home.dart',
            line: 18,
            confidence: 0.85,
            suggestions: const [
              FixSuggestion(
                action: 'Wrap Expanded inside a Column or Row.',
                details:
                    'Expanded requires a Flex ancestor to provide constraints.',
              ),
            ],
          ),
          DiagnosticIssue(
            id: 'ui.missing-tooltip',
            category: DiagnosticCategory.accessibility,
            severity: DiagnosticSeverity.low,
            title: 'IconButton missing tooltip and label',
            description:
                'IconButton widget does not specify a tooltip or semanticsLabel.',
            filePath: 'lib/widgets/action_bar.dart',
            line: 105,
            confidence: 0.95,
            suggestions: const [
              FixSuggestion(
                action: 'Add a tooltip parameter to IconButton.',
                details: 'Tooltips enhance screen reader accessibility.',
              ),
            ],
          ),
        ],
        warnings: const ['lockfile skipped due to missing pubspec.lock'],
        limitations: const ['Runtime frame timings were not measured.'],
      );
    });

    test('Terminal layout renders golden output structure correctly', () {
      final output = DiagnosticReportRenderer.renderTerminal(
        sampleReport,
        colorMode: ColorMode.never,
        commandName: 'ui-doctor',
      );

      expect(output, contains('Flutter Dev Intelligence 1.0.0'));
      expect(output, contains('────────────────────────────────────────────'));
      expect(output, contains('Command:     ui-doctor'));
      expect(output, contains('Project:     demo_app'));
      expect(output, contains('Duration:    184 ms'));
      expect(output, contains('Files analyzed: 42'));
      expect(output, contains('Rules executed: 28'));

      expect(output, contains('Summary'));
      expect(output, contains('  Critical   0'));
      expect(output, contains('  High       1'));
      expect(output, contains('  Medium     1'));
      expect(output, contains('  Low        1'));
      expect(output, contains('  Info       0'));

      expect(
        output,
        contains('[HIGH] Nested scrollables with shrinkWrap detected'),
      );
      expect(output, contains('Location: lib/widgets/my_list.dart:42'));
      expect(output, contains('Rule ID:  ui.nested-scrollable'));
      expect(output, contains('Confidence: 90%'));
      expect(output, contains('Evidence: parent = ListView'));
      expect(
        output,
        contains(
          'Action:   Replace inner GridView with SliverGrid inside CustomScrollView.',
        ),
      );
      expect(
        output,
        contains(
          'Doc:      https://pub.dev/packages/flutter_dev_intelligence#ui.nested-scrollable',
        ),
      );

      expect(output, contains('Analysis status'));
      expect(
        output,
        contains('ACTIONABLE FINDINGS DETECTED — 3 total issue(s) reported.'),
      );
    });

    test('ASCII fallback terminal layout replaces Unicode characters', () {
      final output = DiagnosticReportRenderer.renderTerminal(
        sampleReport,
        colorMode: ColorMode.never,
        commandName: 'ui-doctor',
        useAscii: true,
      );

      expect(output, contains('--------------------------------------------'));
      expect(
        output,
        isNot(contains('────────────────────────────────────────────')),
      );
      expect(
        output,
        contains('[!] lockfile skipped due to missing pubspec.lock'),
      );
      expect(
        output,
        isNot(contains('! lockfile skipped due to missing pubspec.lock')),
      );
    });

    test('Markdown report golden output contains property table and issues', () {
      final markdown = DiagnosticReportRenderer.renderMarkdown(sampleReport);

      expect(markdown, contains('# Flutter Dev Intelligence Report'));
      expect(markdown, contains('| Project | `demo_app` |'));
      expect(markdown, contains('| Path | `/path/to/demo_app` |'));
      expect(markdown, contains('| Duration | 184 ms |'));
      expect(markdown, contains('| Files Analyzed | 42 |'));
      expect(markdown, contains('| Rules Executed | 28 |'));

      expect(markdown, contains('## Summary'));
      expect(markdown, contains('- **Total Issues:** 3'));
      expect(markdown, contains('  - **High:** 1'));
      expect(markdown, contains('  - **Medium:** 1'));
      expect(markdown, contains('  - **Low:** 1'));

      expect(
        markdown,
        contains('### [HIGH] Nested scrollables with shrinkWrap detected'),
      );
      expect(
        markdown,
        contains('- **Location:** `lib/widgets/my_list.dart:42`'),
      );
      expect(markdown, contains('- **Rule ID:** `ui.nested-scrollable`'));
      expect(markdown, contains('- **Confidence:** 90%'));
      expect(
        markdown,
        contains(
          '- **Documentation:** https://pub.dev/packages/flutter_dev_intelligence#ui.nested-scrollable',
        ),
      );
    });

    test('JSON report output contains zero ANSI color codes', () {
      final jsonStr = DiagnosticReportRenderer.renderJson(sampleReport);

      expect(jsonStr, contains('"projectName": "demo_app"'));
      expect(jsonStr, contains('"filesAnalyzed": 42'));
      expect(jsonStr, contains('"rulesExecuted": 28'));
      expect(DiagnosticReportRenderer.ansiRegex.hasMatch(jsonStr), isFalse);
    });

    test(
      'Color behavior evaluates ColorMode.never, ColorMode.always, and NO_COLOR env',
      () {
        expect(
          DiagnosticReportRenderer.isColorEnabled(ColorMode.never),
          isFalse,
        );
        expect(
          DiagnosticReportRenderer.isColorEnabled(ColorMode.always),
          isTrue,
        );
        expect(
          DiagnosticReportRenderer.isColorEnabled(
            ColorMode.auto,
            environment: {'NO_COLOR': '1'},
          ),
          isFalse,
        );
        expect(
          DiagnosticReportRenderer.isColorEnabled(
            ColorMode.auto,
            isTtyOverride: false,
            environment: {},
          ),
          isFalse,
        );
        expect(
          DiagnosticReportRenderer.isColorEnabled(
            ColorMode.auto,
            isTtyOverride: true,
            environment: {},
          ),
          isTrue,
        );
      },
    );

    test('Clean empty report displays PASSED status', () {
      final cleanReport = DiagnosticReport(
        id: 'clean_123',
        createdAt: DateTime.utc(2026, 9, 12),
        projectName: 'clean_app',
        issues: const [],
      );

      final output = DiagnosticReportRenderer.renderTerminal(
        cleanReport,
        colorMode: ColorMode.never,
      );

      expect(output, contains('✓ No diagnostic issues detected.'));
      expect(output, contains('PASSED — 0 actionable issues found.'));
    });
  });
}
