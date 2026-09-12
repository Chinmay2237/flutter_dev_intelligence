import 'dart:io';

import '../core/config.dart';
import '../core/models.dart';
import 'ast_parser.dart';
import 'ast_source_discoverer.dart';
import 'rule_executor.dart';

/// Result of parsing and inspecting one Dart source file.
class UiAstAnalysisResult {
  const UiAstAnalysisResult({
    required this.filePath,
    required this.issues,
    required this.parseErrors,
    this.metrics = const [],
  });

  final String filePath;
  final List<DiagnosticIssue> issues;
  final List<String> parseErrors;
  final List<dynamic> metrics;

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'issues': issues.map((issue) => issue.toJson()).toList(),
    'parseErrors': parseErrors,
  };
}

/// Performs conservative, AST-backed Flutter layout heuristics.
class UiAstAnalyzer {
  const UiAstAnalyzer({this.registry = const UiAstRuleRegistry()});

  final UiAstRuleRegistry registry;

  /// Analyzes Dart source without resolving imports or executing code.
  static UiAstAnalysisResult analyzeSource(
    String source, {
    String filePath = '<memory>',
    UiAstRuleRegistry registry = const UiAstRuleRegistry(),
    ProjectConfig config = const ProjectConfig(),
  }) {
    final parseResult = AstParser.parse(source, filePath: filePath);
    final parseErrors = parseResult.parseErrors
        .map((e) => e.toString())
        .toList();

    if (parseResult.unit == null || parseResult.lineInfo == null) {
      return UiAstAnalysisResult(
        filePath: filePath,
        issues: const <DiagnosticIssue>[],
        parseErrors: parseErrors,
      );
    }

    final execResult = RuleExecutor.execute(
      unit: parseResult.unit!,
      filePath: filePath,
      lineInfo: parseResult.lineInfo!,
      registry: registry,
      config: config,
    );

    final issues = DiagnosticFilter.filterIssues(execResult.issues, config);

    return UiAstAnalysisResult(
      filePath: filePath,
      issues: issues,
      parseErrors: parseErrors,
      metrics: execResult.metrics,
    );
  }

  /// Reads and analyzes a Dart file from disk.
  static Future<UiAstAnalysisResult> analyzeFile(
    String filePath, {
    UiAstRuleRegistry registry = const UiAstRuleRegistry(),
    ProjectConfig config = const ProjectConfig(),
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return UiAstAnalysisResult(
        filePath: filePath,
        issues: const <DiagnosticIssue>[],
        parseErrors: ['File not found: $filePath'],
      );
    }
    return analyzeSource(
      await file.readAsString(),
      filePath: filePath,
      registry: registry,
      config: config,
    );
  }

  /// Analyzes Dart files below a project `lib` directory in stable path order using [AstSourceDiscoverer].
  static Future<List<UiAstAnalysisResult>> analyzeDirectory(
    String directoryPath, {
    UiAstRuleRegistry registry = const UiAstRuleRegistry(),
    ProjectConfig config = const ProjectConfig(),
    AstSourceDiscoverer discoverer = const AstSourceDiscoverer(),
  }) async {
    final discovery = await discoverer.discover(directoryPath, config: config);
    final results = <UiAstAnalysisResult>[];

    for (final path in discovery.discoveredPaths) {
      final res = await analyzeFile(path, registry: registry, config: config);
      results.add(res);
    }

    return results;
  }
}
