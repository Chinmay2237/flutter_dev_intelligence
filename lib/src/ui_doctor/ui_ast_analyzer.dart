import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';

import '../core/models.dart';
import 'ui_ast_rule.dart';

/// Result of parsing and inspecting one Dart source file.
class UiAstAnalysisResult {
  const UiAstAnalysisResult({
    required this.filePath,
    required this.issues,
    required this.parseErrors,
  });

  final String filePath;
  final List<DiagnosticIssue> issues;
  final List<String> parseErrors;

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
  }) {
    final parsed = parseString(
      content: source,
      path: filePath,
      throwIfDiagnostics: false,
    );
    final parseErrors = parsed.errors
        .map((error) => '${error.message} at ${error.offset}')
        .toList(growable: false);
    final issues = registry.analyze(parsed.unit, filePath);
    return UiAstAnalysisResult(
      filePath: filePath,
      issues: issues,
      parseErrors: parseErrors,
    );
  }

  /// Reads and analyzes a Dart file from disk.
  static Future<UiAstAnalysisResult> analyzeFile(
    String filePath, {
    UiAstRuleRegistry registry = const UiAstRuleRegistry(),
  }) async {
    return analyzeSource(
      await File(filePath).readAsString(),
      filePath: filePath,
      registry: registry,
    );
  }

  /// Analyzes Dart files below a project `lib` directory in stable path order.
  static Future<List<UiAstAnalysisResult>> analyzeDirectory(
    String directoryPath, {
    UiAstRuleRegistry registry = const UiAstRuleRegistry(),
  }) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return const <UiAstAnalysisResult>[];
    }
    final paths = await directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File && entity.path.endsWith('.dart'))
        .map((entity) => entity.path)
        .toList();
    paths.sort();
    return [
      for (final path in paths) await analyzeFile(path, registry: registry),
    ];
  }
}
