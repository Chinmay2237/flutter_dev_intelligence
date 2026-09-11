import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/models.dart';

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
  const UiAstAnalyzer();

  /// Analyzes Dart source without resolving imports or executing code.
  static UiAstAnalysisResult analyzeSource(
    String source, {
    String filePath = '<memory>',
  }) {
    final parsed = parseString(
      content: source,
      path: filePath,
      throwIfDiagnostics: false,
    );
    final parseErrors = parsed.errors
        .map((error) => '${error.message} at ${error.offset}')
        .toList(growable: false);
    final visitor = _UiAstVisitor(filePath, parsed.unit.lineInfo);
    parsed.unit.accept(visitor);
    return UiAstAnalysisResult(
      filePath: filePath,
      issues: visitor.issues,
      parseErrors: parseErrors,
    );
  }

  /// Reads and analyzes a Dart file from disk.
  static Future<UiAstAnalysisResult> analyzeFile(String filePath) async {
    return analyzeSource(
      await File(filePath).readAsString(),
      filePath: filePath,
    );
  }

  /// Analyzes Dart files below a project `lib` directory in stable path order.
  static Future<List<UiAstAnalysisResult>> analyzeDirectory(
    String directoryPath,
  ) async {
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
    return [for (final path in paths) await analyzeFile(path)];
  }
}

class _UiAstVisitor extends RecursiveAstVisitor<void> {
  _UiAstVisitor(this.filePath, this.lineInfo);

  final String filePath;
  final dynamic lineInfo;
  final List<DiagnosticIssue> issues = <DiagnosticIssue>[];
  final Set<String> _issueKeys = <String>{};
  final List<String> _scrollableStack = <String>[];

  static const _scrollables = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SingleChildScrollView',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    final isScrollable = _scrollables.contains(typeName);
    if (isScrollable) {
      _scrollableStack.add(typeName);
    }
    try {
      if (isScrollable && _scrollableStack.length > 1) {
        _addIssue(
          node,
          id: 'ui_nested_scrollable',
          title: 'Nested scrollable may cause layout or gesture conflicts',
          description:
              'A scrollable widget is nested inside another scrollable widget. Static analysis cannot determine whether constraints and scroll physics make this intentional.',
          severity: DiagnosticSeverity.medium,
          evidence: node.toSource(),
          suggestion:
              'Verify the parent constraints and consider one coordinated scrollable when nested scrolling is not intentional.',
          confidence: 0.78,
        );
      }

      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'shrinkWrap' &&
            argument.expression.toSource() == 'true' &&
            isScrollable &&
            _scrollableStack.length > 1) {
          _addIssue(
            argument,
            id: 'ui_nested_shrink_wrap',
            title: 'Nested shrink-wrapped scrollable may be expensive',
            description:
                'A nested scrollable uses shrinkWrap: true, which can require measuring more children during layout.',
            severity: DiagnosticSeverity.low,
            evidence: argument.toSource(),
            suggestion:
                'Use shrinkWrap only when the bounded parent and expected child count justify its layout cost.',
            confidence: 0.72,
          );
        }
      }

      super.visitInstanceCreationExpression(node);
    } finally {
      if (isScrollable) {
        _scrollableStack.removeLast();
      }
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target;
    final typeName = target is SimpleIdentifier
        ? target.name
        : target == null
        ? methodName
        : null;
    final isScrollable = typeName != null && _scrollables.contains(typeName);
    if (!isScrollable) {
      super.visitMethodInvocation(node);
      return;
    }

    _scrollableStack.add(typeName);
    try {
      if (_scrollableStack.length > 1) {
        _addIssue(
          node,
          id: 'ui_nested_scrollable',
          title: 'Nested scrollable may cause layout or gesture conflicts',
          description:
              'A scrollable widget is nested inside another scrollable widget. Static analysis cannot determine whether constraints and scroll physics make this intentional.',
          severity: DiagnosticSeverity.medium,
          evidence: node.toSource(),
          suggestion:
              'Verify the parent constraints and consider one coordinated scrollable when nested scrolling is not intentional.',
          confidence: 0.78,
        );
      }
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'shrinkWrap' &&
            argument.expression.toSource() == 'true' &&
            _scrollableStack.length > 1) {
          _addIssue(
            argument,
            id: 'ui_nested_shrink_wrap',
            title: 'Nested shrink-wrapped scrollable may be expensive',
            description:
                'A nested scrollable uses shrinkWrap: true, which can require measuring more children during layout.',
            severity: DiagnosticSeverity.low,
            evidence: argument.toSource(),
            suggestion:
                'Use shrinkWrap only when the bounded parent and expected child count justify its layout cost.',
            confidence: 0.72,
          );
        }
      }
      super.visitMethodInvocation(node);
    } finally {
      _scrollableStack.removeLast();
    }
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if ((name == 'width' || name == 'height') &&
        node.expression is IntegerLiteral) {
      final value = (node.expression as IntegerLiteral).value;
      if (value != null && value > 1000) {
        _addIssue(
          node,
          id: 'ui_oversized_dimension',
          title: 'Large hardcoded layout dimension detected',
          description:
              'A hardcoded $name larger than 1000 logical pixels may be fragile across devices.',
          severity: DiagnosticSeverity.low,
          evidence: node.toSource(),
          suggestion:
              'Prefer constraints or responsive sizing when this dimension is not intentionally fixed.',
          confidence: 0.7,
        );
      }
    }
    super.visitNamedExpression(node);
  }

  void _addIssue(
    AstNode node, {
    required String id,
    required String title,
    required String description,
    required DiagnosticSeverity severity,
    required String evidence,
    required String suggestion,
    required double confidence,
  }) {
    final location = lineInfo.getLocation(node.offset);
    final key = '$id:${location.lineNumber}:${location.columnNumber}';
    if (!_issueKeys.add(key)) {
      return;
    }
    issues.add(
      DiagnosticIssue(
        id: id,
        category: DiagnosticCategory.layout,
        severity: severity,
        title: title,
        description: description,
        filePath: filePath,
        line: location.lineNumber,
        evidence: [
          EvidenceReference(
            type: EvidenceType.sourceFile,
            label: filePath,
            value: evidence,
            metadata: <String, dynamic>{
              'column': location.columnNumber,
              'analysis': 'static-heuristic',
            },
          ),
        ],
        suggestions: [FixSuggestion(action: suggestion, details: suggestion)],
        confidence: confidence,
        source: 'static',
        limitation:
            'This is a source heuristic. Only runtime Flutter layout diagnostics can confirm an actual overflow or performance problem.',
      ),
    );
  }
}
