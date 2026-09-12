import 'dart:io';
import 'package:yaml/yaml.dart';

import 'models.dart';

/// Suppression rule definition for suppressing specific diagnostics.
class SuppressionRule {
  const SuppressionRule({
    required this.rule,
    this.file,
    this.line,
    this.reason,
    this.expirationDate,
    this.owner,
  });

  final String rule;
  final String? file;
  final int? line;
  final String? reason;
  final DateTime? expirationDate;
  final String? owner;

  /// Evaluates whether a diagnostic issue is suppressed by this rule.
  bool suppresses(DiagnosticIssue issue) {
    // Check if suppression has expired
    if (expirationDate != null && DateTime.now().isAfter(expirationDate!)) {
      return false;
    }

    // Check rule ID match (wildcard '*' matches all rules)
    if (rule != '*' && issue.id != rule && !issue.id.startsWith('$rule.')) {
      return false;
    }

    // Check file match
    if (file != null && file!.isNotEmpty) {
      final issuePath = issue.filePath;
      if (issuePath == null || issuePath.isEmpty) return false;
      if (!matchPathPattern(issuePath, file!)) {
        return false;
      }
    }

    // Check line match
    if (line != null && line! > 0) {
      if (issue.line == null || issue.line != line) {
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> toJson() => {
    'rule': rule,
    if (file != null) 'file': file,
    if (line != null) 'line': line,
    if (reason != null) 'reason': reason,
    if (expirationDate != null)
      'expiration_date': expirationDate!.toIso8601String(),
    if (owner != null) 'owner': owner,
  };

  factory SuppressionRule.fromJson(Map<String, dynamic> json) {
    return SuppressionRule(
      rule: json['rule']?.toString() ?? '*',
      file: json['file']?.toString(),
      line: json['line'] is int
          ? json['line'] as int
          : int.tryParse(json['line']?.toString() ?? ''),
      reason: json['reason']?.toString(),
      expirationDate: json['expiration_date'] != null
          ? DateTime.tryParse(json['expiration_date'].toString())
          : null,
      owner: json['owner']?.toString(),
    );
  }
}

/// Result of validating a ProjectConfig file.
class ConfigValidationResult {
  const ConfigValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.config,
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final ProjectConfig config;
}

/// Project-level configuration schema for flutter_dev_intelligence.yaml.
class ProjectConfig {
  const ProjectConfig({
    this.version = 1,
    this.severityThreshold = DiagnosticSeverity.info,
    this.confidenceThreshold = 0.0,
    this.enableBuildDoctor = true,
    this.enableUiDoctor = true,
    this.enablePerformance = true,
    this.excludePaths = const <String>[
      'build/**',
      '.dart_tool/**',
      '**/generated/**',
      '**/*.g.dart',
      '**/*.freezed.dart',
      '**/*.pb.dart',
      '**/*.gen.dart',
    ],
    this.includePaths = const <String>[],
    this.excludeTests = false,
    this.excludeExamples = false,
    this.excludeGenerated = true,
    this.disabledRules = const <String>{},
    this.enabledRules,
    this.refreshRateHz = 60.0,
    this.frameBudgetMs = 16.67,
    this.aiEnabled = false,
    this.aiProvider,
    this.redactSecrets = true,
    this.defaultFormat = 'terminal',
    this.defaultColor = 'auto',
    this.quiet = false,
    this.verbose = false,
    this.maxFileSizeBytes = 2097152,
    this.maxLogSizeBytes = 10485760,
    this.maxTraceEvents = 50000,
    this.maxIssuesCount = 500,
    this.suppressions = const <SuppressionRule>[],
  });

  final int version;
  final DiagnosticSeverity severityThreshold;
  final double confidenceThreshold;
  final bool enableBuildDoctor;
  final bool enableUiDoctor;
  final bool enablePerformance;
  final List<String> excludePaths;
  final List<String> includePaths;
  final bool excludeTests;
  final bool excludeExamples;
  final bool excludeGenerated;
  final Set<String> disabledRules;
  final Set<String>? enabledRules;
  final double refreshRateHz;
  final double frameBudgetMs;
  final bool aiEnabled;
  final String? aiProvider;
  final bool redactSecrets;
  final String defaultFormat;
  final String defaultColor;
  final bool quiet;
  final bool verbose;
  final int maxFileSizeBytes;
  final int maxLogSizeBytes;
  final int maxTraceEvents;
  final int maxIssuesCount;
  final List<SuppressionRule> suppressions;

  /// Returns true if a given relative file path should be excluded based on config rules.
  bool shouldExcludePath(String filePath) {
    final normalized = normalizePath(filePath);

    // Generated file check
    if (excludeGenerated && isGeneratedFile(normalized)) {
      return true;
    }

    // Test file check
    if (excludeTests &&
        (normalized.startsWith('test/') || normalized.contains('/test/'))) {
      return true;
    }

    // Example file check
    if (excludeExamples &&
        (normalized.startsWith('example/') ||
            normalized.contains('/example/'))) {
      return true;
    }

    // Exclude path patterns
    for (final pattern in excludePaths) {
      if (matchPathPattern(normalized, pattern)) {
        return true;
      }
    }

    // Include path patterns
    if (includePaths.isNotEmpty) {
      var matched = false;
      for (final pattern in includePaths) {
        if (matchPathPattern(normalized, pattern)) {
          matched = true;
          break;
        }
      }
      if (!matched) return true;
    }

    return false;
  }

  /// Parses YAML text into a validated ProjectConfig.
  static ConfigValidationResult parseYaml(
    String yamlContent, {
    String? sourcePath,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (yamlContent.trim().isEmpty) {
      return const ConfigValidationResult(
        isValid: true,
        errors: [],
        warnings: ['Configuration file is empty. Using default configuration.'],
        config: ProjectConfig(),
      );
    }

    YamlMap doc;
    try {
      final parsed = loadYaml(yamlContent);
      if (parsed is! YamlMap) {
        return const ConfigValidationResult(
          isValid: false,
          errors: ['Configuration root must be a YAML map.'],
          warnings: [],
          config: ProjectConfig(),
        );
      }
      doc = parsed;
    } catch (e) {
      return ConfigValidationResult(
        isValid: false,
        errors: ['Failed to parse YAML configuration: $e'],
        warnings: const [],
        config: const ProjectConfig(),
      );
    }

    final recognizedKeys = const {
      'version',
      'analysis',
      'paths',
      'rules',
      'performance',
      'ai',
      'privacy',
      'output',
      'limits',
      'suppressions',
    };

    for (final key in doc.keys) {
      final keyStr = key.toString();
      if (!recognizedKeys.contains(keyStr)) {
        warnings.add('Unknown configuration top-level key "$keyStr".');
      }
    }

    final version = doc['version'] is int ? doc['version'] as int : 1;
    if (version != 1) {
      errors.add(
        'Unsupported configuration version "$version". Expected version 1.',
      );
    }

    var severityThreshold = DiagnosticSeverity.info;
    var confidenceThreshold = 0.0;
    var enableBuildDoctor = true;
    var enableUiDoctor = true;
    var enablePerformance = true;

    final analysisObj = doc['analysis'];
    if (analysisObj is YamlMap) {
      final recognizedAnalysisKeys = const {
        'severity_threshold',
        'confidence_threshold',
        'enable_build_doctor',
        'enable_ui_doctor',
        'enable_performance',
      };
      for (final k in analysisObj.keys) {
        if (!recognizedAnalysisKeys.contains(k.toString())) {
          warnings.add('Unknown key "$k" inside analysis configuration.');
        }
      }

      if (analysisObj.containsKey('severity_threshold')) {
        final val = analysisObj['severity_threshold']?.toString().toLowerCase();
        switch (val) {
          case 'info':
            severityThreshold = DiagnosticSeverity.info;
            break;
          case 'low':
            severityThreshold = DiagnosticSeverity.low;
            break;
          case 'medium':
            severityThreshold = DiagnosticSeverity.medium;
            break;
          case 'high':
            severityThreshold = DiagnosticSeverity.high;
            break;
          case 'critical':
            severityThreshold = DiagnosticSeverity.critical;
            break;
          default:
            errors.add(
              'Invalid severity_threshold "$val". Must be one of: info, low, medium, high, critical.',
            );
        }
      }

      if (analysisObj.containsKey('confidence_threshold')) {
        final raw = analysisObj['confidence_threshold'];
        if (raw is num) {
          final val = raw.toDouble();
          if (val < 0.0 || val > 1.0) {
            errors.add(
              'Invalid confidence_threshold "$val". Must be between 0.0 and 1.0.',
            );
          } else {
            confidenceThreshold = val;
          }
        } else {
          errors.add('confidence_threshold must be a number.');
        }
      }

      if (analysisObj.containsKey('enable_build_doctor')) {
        enableBuildDoctor = analysisObj['enable_build_doctor'] == true;
      }
      if (analysisObj.containsKey('enable_ui_doctor')) {
        enableUiDoctor = analysisObj['enable_ui_doctor'] == true;
      }
      if (analysisObj.containsKey('enable_performance')) {
        enablePerformance = analysisObj['enable_performance'] == true;
      }
    }

    var excludePaths = List<String>.from(const [
      'build/**',
      '.dart_tool/**',
      '**/generated/**',
      '**/*.g.dart',
      '**/*.freezed.dart',
      '**/*.pb.dart',
      '**/*.gen.dart',
    ]);
    var includePaths = <String>[];
    var excludeTests = false;
    var excludeExamples = false;
    var excludeGenerated = true;

    final pathsObj = doc['paths'];
    if (pathsObj is YamlMap) {
      if (pathsObj['exclude'] is YamlList) {
        excludePaths = (pathsObj['exclude'] as YamlList)
            .map((e) => e.toString())
            .toList();
      }
      if (pathsObj['include'] is YamlList) {
        includePaths = (pathsObj['include'] as YamlList)
            .map((e) => e.toString())
            .toList();
      }
      if (pathsObj.containsKey('exclude_tests')) {
        excludeTests = pathsObj['exclude_tests'] == true;
      }
      if (pathsObj.containsKey('exclude_examples')) {
        excludeExamples = pathsObj['exclude_examples'] == true;
      }
      if (pathsObj.containsKey('exclude_generated')) {
        excludeGenerated = pathsObj['exclude_generated'] == true;
      }
    }

    final disabledRules = <String>{};
    Set<String>? enabledRules;

    final rulesObj = doc['rules'];
    if (rulesObj is YamlMap) {
      if (rulesObj['disabled'] is YamlList) {
        for (final item in (rulesObj['disabled'] as YamlList)) {
          disabledRules.add(item.toString().trim());
        }
      }
      if (rulesObj['enabled'] is YamlList) {
        enabledRules = <String>{};
        for (final item in (rulesObj['enabled'] as YamlList)) {
          enabledRules.add(item.toString().trim());
        }
      }
    }

    var refreshRateHz = 60.0;
    var frameBudgetMs = 16.67;

    final perfObj = doc['performance'];
    if (perfObj is YamlMap) {
      if (perfObj.containsKey('refresh_rate_hz')) {
        final raw = perfObj['refresh_rate_hz'];
        if (raw is num && raw > 0) {
          refreshRateHz = raw.toDouble();
          frameBudgetMs = 1000.0 / refreshRateHz;
        } else {
          errors.add('refresh_rate_hz must be a positive number.');
        }
      }
      if (perfObj.containsKey('frame_budget_ms')) {
        final raw = perfObj['frame_budget_ms'];
        if (raw is num && raw > 0) {
          frameBudgetMs = raw.toDouble();
        } else {
          errors.add('frame_budget_ms must be a positive number.');
        }
      }
    }

    var aiEnabled = false;
    String? aiProvider;
    var redactSecrets = true;

    final aiObj = doc['ai'];
    if (aiObj is YamlMap) {
      if (aiObj.containsKey('enabled')) {
        aiEnabled = aiObj['enabled'] == true;
      }
      if (aiObj.containsKey('provider')) {
        aiProvider = aiObj['provider']?.toString();
      }
    }

    final privacyObj = doc['privacy'];
    if (privacyObj is YamlMap) {
      if (privacyObj.containsKey('redact_secrets')) {
        redactSecrets = privacyObj['redact_secrets'] == true;
      }
    }

    var defaultFormat = 'terminal';
    var defaultColor = 'auto';
    var quiet = false;
    var verbose = false;

    final outputObj = doc['output'];
    if (outputObj is YamlMap) {
      if (outputObj.containsKey('format')) {
        final fmt = outputObj['format']?.toString().toLowerCase();
        if (const {'terminal', 'json', 'markdown'}.contains(fmt)) {
          defaultFormat = fmt!;
        } else {
          errors.add(
            'Invalid output format "$fmt". Choose terminal, json, or markdown.',
          );
        }
      }
      if (outputObj.containsKey('color')) {
        final col = outputObj['color']?.toString().toLowerCase();
        if (const {'auto', 'always', 'never'}.contains(col)) {
          defaultColor = col!;
        } else {
          errors.add(
            'Invalid color mode "$col". Choose auto, always, or never.',
          );
        }
      }
      if (outputObj.containsKey('quiet')) {
        quiet = outputObj['quiet'] == true;
      }
      if (outputObj.containsKey('verbose')) {
        verbose = outputObj['verbose'] == true;
      }
    }

    var maxFileSizeBytes = 2097152;
    var maxLogSizeBytes = 10485760;
    var maxTraceEvents = 50000;
    var maxIssuesCount = 500;

    final limitsObj = doc['limits'];
    if (limitsObj is YamlMap) {
      if (limitsObj['max_file_size_bytes'] is int) {
        maxFileSizeBytes = limitsObj['max_file_size_bytes'] as int;
      }
      if (limitsObj['max_log_size_bytes'] is int) {
        maxLogSizeBytes = limitsObj['max_log_size_bytes'] as int;
      }
      if (limitsObj['max_trace_events'] is int) {
        maxTraceEvents = limitsObj['max_trace_events'] as int;
      }
      if (limitsObj['max_issues_count'] is int) {
        maxIssuesCount = limitsObj['max_issues_count'] as int;
      }
    }

    final suppressions = <SuppressionRule>[];
    final suppObj = doc['suppressions'];
    if (suppObj is YamlList) {
      for (final item in suppObj) {
        if (item is YamlMap) {
          final rule = item['rule']?.toString();
          if (rule == null || rule.isEmpty) {
            errors.add('Suppression item missing required "rule" field.');
            continue;
          }
          suppressions.add(
            SuppressionRule(
              rule: rule,
              file: item['file']?.toString(),
              line: item['line'] is int
                  ? item['line'] as int
                  : int.tryParse(item['line']?.toString() ?? ''),
              reason: item['reason']?.toString(),
              expirationDate: item['expiration_date'] != null
                  ? DateTime.tryParse(item['expiration_date'].toString())
                  : null,
              owner: item['owner']?.toString(),
            ),
          );
        } else {
          errors.add('Suppression item must be a map.');
        }
      }
    }

    final isValid = errors.isEmpty;
    final config = ProjectConfig(
      version: version,
      severityThreshold: severityThreshold,
      confidenceThreshold: confidenceThreshold,
      enableBuildDoctor: enableBuildDoctor,
      enableUiDoctor: enableUiDoctor,
      enablePerformance: enablePerformance,
      excludePaths: excludePaths,
      includePaths: includePaths,
      excludeTests: excludeTests,
      excludeExamples: excludeExamples,
      excludeGenerated: excludeGenerated,
      disabledRules: disabledRules,
      enabledRules: enabledRules,
      refreshRateHz: refreshRateHz,
      frameBudgetMs: frameBudgetMs,
      aiEnabled: aiEnabled,
      aiProvider: aiProvider,
      redactSecrets: redactSecrets,
      defaultFormat: defaultFormat,
      defaultColor: defaultColor,
      quiet: quiet,
      verbose: verbose,
      maxFileSizeBytes: maxFileSizeBytes,
      maxLogSizeBytes: maxLogSizeBytes,
      maxTraceEvents: maxTraceEvents,
      maxIssuesCount: maxIssuesCount,
      suppressions: suppressions,
    );

    return ConfigValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
      config: config,
    );
  }

  /// Locates and loads configuration file for a project path.
  static Future<ConfigValidationResult> findAndLoad(
    String projectPath, {
    String? customConfigPath,
  }) async {
    if (customConfigPath != null && customConfigPath.isNotEmpty) {
      final file = File(customConfigPath);
      if (!await file.exists()) {
        return ConfigValidationResult(
          isValid: false,
          errors: ['Specified configuration file not found: $customConfigPath'],
          warnings: const [],
          config: const ProjectConfig(),
        );
      }
      final text = await file.readAsString();
      return parseYaml(text, sourcePath: customConfigPath);
    }

    final dir = Directory(projectPath);
    final primaryPath =
        '${dir.path}${Platform.pathSeparator}flutter_dev_intelligence.yaml';
    final primaryFile = File(primaryPath);
    if (await primaryFile.exists()) {
      final text = await primaryFile.readAsString();
      return parseYaml(text, sourcePath: primaryPath);
    }

    final altPath =
        '${dir.path}${Platform.pathSeparator}.flutter_dev_intelligence.yaml';
    final altFile = File(altPath);
    if (await altFile.exists()) {
      final text = await altFile.readAsString();
      return parseYaml(text, sourcePath: altPath);
    }

    return const ConfigValidationResult(
      isValid: true,
      errors: [],
      warnings: [],
      config: ProjectConfig(),
    );
  }
}

/// Diagnostic issue filter applying ProjectConfig rules, severity, confidence, and suppressions.
class DiagnosticFilter {
  static List<DiagnosticIssue> filterIssues(
    List<DiagnosticIssue> issues,
    ProjectConfig config,
  ) {
    final filtered = issues
        .where((issue) => !shouldFilterIssue(issue, config))
        .toList();
    if (config.maxIssuesCount > 0 && filtered.length > config.maxIssuesCount) {
      return filtered.take(config.maxIssuesCount).toList();
    }
    return filtered;
  }

  static bool shouldFilterIssue(DiagnosticIssue issue, ProjectConfig config) {
    // 1. Severity threshold filter
    if (_severityIndex(issue.severity) <
        _severityIndex(config.severityThreshold)) {
      return true;
    }

    // 2. Confidence threshold filter
    if (issue.confidence != null &&
        issue.confidence! < config.confidenceThreshold) {
      return true;
    }

    // 3. Disabled rules filter
    if (config.disabledRules.contains(issue.id)) {
      return true;
    }

    // 4. Enabled rules filter (if specified)
    if (config.enabledRules != null &&
        config.enabledRules!.isNotEmpty &&
        !config.enabledRules!.contains(issue.id)) {
      return true;
    }

    // 5. File path exclusion filters
    final path = issue.filePath;
    if (path != null && path.isNotEmpty) {
      if (config.shouldExcludePath(path)) {
        return true;
      }
    }

    // 6. Suppression rules filter
    for (final suppression in config.suppressions) {
      if (suppression.suppresses(issue)) {
        return true;
      }
    }

    return false;
  }

  static int _severityIndex(DiagnosticSeverity severity) {
    return switch (severity) {
      DiagnosticSeverity.info => 0,
      DiagnosticSeverity.low => 1,
      DiagnosticSeverity.medium => 2,
      DiagnosticSeverity.high => 3,
      DiagnosticSeverity.critical => 4,
    };
  }
}

/// Utility functions for path normalization, generated file checks, and glob matching.
String normalizePath(String rawPath) {
  var p = rawPath.replaceAll('\\', '/');
  if (p.startsWith('./')) {
    p = p.substring(2);
  }
  return p;
}

bool isGeneratedFile(String path) {
  final norm = normalizePath(path);
  return norm.endsWith('.g.dart') ||
      norm.endsWith('.freezed.dart') ||
      norm.endsWith('.pb.dart') ||
      norm.endsWith('.gen.dart') ||
      norm.endsWith('.gr.dart') ||
      norm.endsWith('.generated.dart') ||
      norm.contains('/generated/') ||
      norm.contains('/.dart_tool/') ||
      norm.startsWith('build/') ||
      norm.contains('/build/');
}

bool matchPathPattern(String path, String pattern) {
  final normPath = normalizePath(path);
  final normPattern = normalizePath(pattern);

  if (normPath == normPattern) return true;

  final regexStr = _globToRegexString(normPattern);
  final regex = RegExp(regexStr, caseSensitive: true);
  return regex.hasMatch(normPath);
}

String _globToRegexString(String pattern) {
  final buffer = StringBuffer('^');
  var i = 0;
  while (i < pattern.length) {
    final c = pattern[i];
    if (c == '*') {
      if (i + 1 < pattern.length && pattern[i + 1] == '*') {
        buffer.write('.*');
        i += 2;
        if (i < pattern.length && pattern[i] == '/') {
          buffer.write(r'(?:/|$)');
          i++;
        }
      } else {
        buffer.write('[^/]*');
        i++;
      }
    } else if (c == '?') {
      buffer.write('[^/]');
      i++;
    } else if (r'.+^$\|()[]{}'.contains(c)) {
      buffer.write('\\$c');
      i++;
    } else {
      buffer.write(c);
      i++;
    }
  }
  buffer.write(r'$');
  return buffer.toString();
}
