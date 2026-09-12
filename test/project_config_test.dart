import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectConfig - Defaults & Empty', () {
    test('Default configuration has expected initial values', () {
      const config = ProjectConfig();
      expect(config.version, 1);
      expect(config.severityThreshold, DiagnosticSeverity.info);
      expect(config.confidenceThreshold, 0.0);
      expect(config.enableBuildDoctor, isTrue);
      expect(config.enableUiDoctor, isTrue);
      expect(config.enablePerformance, isTrue);
      expect(config.excludeGenerated, isTrue);
      expect(config.disabledRules, isEmpty);
      expect(config.suppressions, isEmpty);
    });

    test('Empty YAML returns valid default config with warning', () {
      final result = ProjectConfig.parseYaml('');
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, contains(contains('empty')));
      expect(result.config.version, 1);
    });

    test('Whitespace-only YAML returns valid default config', () {
      final result = ProjectConfig.parseYaml('   \n  \n');
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });
  });

  group('ProjectConfig - Valid Parsing', () {
    test('Parses full valid YAML configuration', () {
      const yaml = '''
version: 1

analysis:
  severity_threshold: medium
  confidence_threshold: 0.75
  enable_build_doctor: true
  enable_ui_doctor: true
  enable_performance: false

paths:
  exclude:
    - build/**
    - custom_generated/**
  include:
    - lib/**
  exclude_tests: true
  exclude_examples: true
  exclude_generated: true

rules:
  disabled:
    - ui.oversized-dimension
  enabled:
    - ui.hardcoded-color

performance:
  refresh_rate_hz: 120.0

ai:
  enabled: false
  provider: mock

privacy:
  redact_secrets: true

output:
  format: json
  color: never
  quiet: true
  verbose: false

suppressions:
  - rule: ui.oversized-dimension
    file: lib/screens/home.dart
    reason: Intentional responsive layout
    owner: UI-Team
''';

      final result = ProjectConfig.parseYaml(yaml);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);

      final config = result.config;
      expect(config.version, 1);
      expect(config.severityThreshold, DiagnosticSeverity.medium);
      expect(config.confidenceThreshold, 0.75);
      expect(config.enablePerformance, isFalse);
      expect(config.excludeTests, isTrue);
      expect(config.excludeExamples, isTrue);
      expect(config.disabledRules, contains('ui.oversized-dimension'));
      expect(config.enabledRules, contains('ui.hardcoded-color'));
      expect(config.refreshRateHz, 120.0);
      expect(config.frameBudgetMs, closeTo(8.33, 0.01));
      expect(config.defaultFormat, 'json');
      expect(config.defaultColor, 'never');
      expect(config.quiet, isTrue);
      expect(config.suppressions, hasLength(1));
      expect(config.suppressions.first.rule, 'ui.oversized-dimension');
      expect(config.suppressions.first.file, 'lib/screens/home.dart');
      expect(config.suppressions.first.owner, 'UI-Team');
    });
  });

  group('ProjectConfig - Validation & Error Reporting', () {
    test('Rejects version mismatch', () {
      final result = ProjectConfig.parseYaml('version: 2');
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(contains('Unsupported configuration version "2"')),
      );
    });

    test('Rejects invalid severity threshold', () {
      final result = ProjectConfig.parseYaml('''
version: 1
analysis:
  severity_threshold: ultra_high
''');
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Invalid severity_threshold'));
    });

    test('Rejects confidence threshold out of range', () {
      final result = ProjectConfig.parseYaml('''
version: 1
analysis:
  confidence_threshold: 1.5
''');
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Must be between 0.0 and 1.0'));
    });

    test('Rejects negative refresh rate', () {
      final result = ProjectConfig.parseYaml('''
version: 1
performance:
  refresh_rate_hz: -60
''');
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('must be a positive number'));
    });

    test('Rejects invalid output format', () {
      final result = ProjectConfig.parseYaml('''
version: 1
output:
  format: html
''');
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Invalid output format "html"'));
    });

    test('Reports warnings for unknown top-level and section keys', () {
      final result = ProjectConfig.parseYaml('''
version: 1
unknown_section:
  foo: bar
analysis:
  unknown_setting: 123
''');
      expect(result.isValid, isTrue);
      expect(
        result.warnings,
        contains(
          contains('Unknown configuration top-level key "unknown_section"'),
        ),
      );
      expect(
        result.warnings,
        contains(contains('Unknown key "unknown_setting"')),
      );
    });
  });

  group('Path Normalization & Glob Matching', () {
    test('normalizePath converts backslashes and strips ./ prefix', () {
      expect(normalizePath(r'lib\src\file.dart'), 'lib/src/file.dart');
      expect(normalizePath(r'.\lib\main.dart'), 'lib/main.dart');
      expect(normalizePath('./test/widget_test.dart'), 'test/widget_test.dart');
    });

    test('isGeneratedFile matches standard generated patterns', () {
      expect(isGeneratedFile('lib/user.g.dart'), isTrue);
      expect(isGeneratedFile('lib/user.freezed.dart'), isTrue);
      expect(isGeneratedFile('lib/service.pb.dart'), isTrue);
      expect(isGeneratedFile('lib/assets.gen.dart'), isTrue);
      expect(isGeneratedFile('lib/generated/l10n.dart'), isTrue);
      expect(isGeneratedFile('.dart_tool/build/entry.dart'), isTrue);
      expect(isGeneratedFile('build/app/outputs/apk/app.apk'), isTrue);
      expect(isGeneratedFile('lib/user_screen.dart'), isFalse);
    });

    test('matchPathPattern supports POSIX and Windows glob syntax', () {
      expect(matchPathPattern('lib/src/home.dart', 'lib/**/*.dart'), isTrue);
      expect(matchPathPattern(r'lib\src\home.dart', 'lib/**/*.dart'), isTrue);
      expect(matchPathPattern('build/output.log', 'build/**'), isTrue);
      expect(
        matchPathPattern('test/app_test.dart', 'test/*_test.dart'),
        isTrue,
      );
      expect(matchPathPattern('lib/main.dart', 'test/*'), isFalse);
    });
  });

  group('Suppression System', () {
    const issue = DiagnosticIssue(
      id: 'ui.oversized-dimension',
      category: DiagnosticCategory.layout,
      severity: DiagnosticSeverity.medium,
      title: 'Oversized fixed dimension',
      description: 'Container width exceeds max threshold',
      filePath: 'lib/screens/home.dart',
      line: 42,
    );

    test('Suppresses by exact rule ID and file path', () {
      const rule = SuppressionRule(
        rule: 'ui.oversized-dimension',
        file: 'lib/screens/home.dart',
      );
      expect(rule.suppresses(issue), isTrue);
    });

    test('Does not suppress when file path differs', () {
      const rule = SuppressionRule(
        rule: 'ui.oversized-dimension',
        file: 'lib/screens/details.dart',
      );
      expect(rule.suppresses(issue), isFalse);
    });

    test('Suppresses by rule, file, and line number', () {
      const ruleMatch = SuppressionRule(
        rule: 'ui.oversized-dimension',
        file: 'lib/screens/home.dart',
        line: 42,
      );
      expect(ruleMatch.suppresses(issue), isTrue);

      const ruleNoMatch = SuppressionRule(
        rule: 'ui.oversized-dimension',
        file: 'lib/screens/home.dart',
        line: 100,
      );
      expect(ruleNoMatch.suppresses(issue), isFalse);
    });

    test('Wildcard rule * suppresses all rules for specified file', () {
      const rule = SuppressionRule(rule: '*', file: 'lib/screens/home.dart');
      expect(rule.suppresses(issue), isTrue);
    });

    test('Expired suppression rule is ignored', () {
      final expiredRule = SuppressionRule(
        rule: 'ui.oversized-dimension',
        file: 'lib/screens/home.dart',
        expirationDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredRule.suppresses(issue), isFalse);
    });
  });

  group('DiagnosticFilter - Thresholds & Filtering', () {
    const infoIssue = DiagnosticIssue(
      id: 'info.rule',
      category: DiagnosticCategory.build,
      severity: DiagnosticSeverity.info,
      title: 'Info level issue',
      description: 'Info',
      confidence: 0.5,
    );

    const highIssue = DiagnosticIssue(
      id: 'high.rule',
      category: DiagnosticCategory.build,
      severity: DiagnosticSeverity.high,
      title: 'High level issue',
      description: 'High',
      confidence: 0.9,
      filePath: 'lib/main.dart',
    );

    test('Filters issues below severity threshold', () {
      const config = ProjectConfig(
        severityThreshold: DiagnosticSeverity.medium,
      );
      expect(DiagnosticFilter.shouldFilterIssue(infoIssue, config), isTrue);
      expect(DiagnosticFilter.shouldFilterIssue(highIssue, config), isFalse);
    });

    test('Filters issues below confidence threshold', () {
      const config = ProjectConfig(confidenceThreshold: 0.8);
      expect(DiagnosticFilter.shouldFilterIssue(infoIssue, config), isTrue);
      expect(DiagnosticFilter.shouldFilterIssue(highIssue, config), isFalse);
    });

    test('Filters disabled rules', () {
      const config = ProjectConfig(disabledRules: {'high.rule'});
      expect(DiagnosticFilter.shouldFilterIssue(highIssue, config), isTrue);
    });
  });

  group('Config Discovery & Loading', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'flutter_dev_config_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Locates flutter_dev_intelligence.yaml in project root', () async {
      final configFile = File(
        '${tempDir.path}${Platform.pathSeparator}flutter_dev_intelligence.yaml',
      );
      await configFile.writeAsString('''
version: 1
analysis:
  severity_threshold: high
''');

      final result = await ProjectConfig.findAndLoad(tempDir.path);
      expect(result.isValid, isTrue);
      expect(result.config.severityThreshold, DiagnosticSeverity.high);
    });

    test('Loads custom configuration path when specified', () async {
      final customFile = File(
        '${tempDir.path}${Platform.pathSeparator}custom.yaml',
      );
      await customFile.writeAsString('''
version: 1
analysis:
  severity_threshold: critical
''');

      final result = await ProjectConfig.findAndLoad(
        tempDir.path,
        customConfigPath: customFile.path,
      );
      expect(result.isValid, isTrue);
      expect(result.config.severityThreshold, DiagnosticSeverity.critical);
    });
  });
}
