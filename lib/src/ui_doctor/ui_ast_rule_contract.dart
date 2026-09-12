import 'package:analyzer/dart/ast/ast.dart';

import '../core/models.dart';
import 'ast_analysis_context.dart';

/// Detection capability declared by an AST diagnostic rule.
enum RuleCapability {
  /// AST static pattern heuristic.
  staticAstHeuristic,

  /// Full AST structure verification.
  astStructureVerification,

  /// Layout constraint propagation check.
  constraintPropagation,
}

/// Target applicability for an AST rule.
enum RuleApplicability {
  /// Applies to all Flutter Dart files.
  flutterWidgetFiles,

  /// Applies specifically to build method ASTs.
  buildMethodsOnly,

  /// Applies to widget tree expressions.
  widgetExpressions,
}

/// Execution metrics captured per rule.
class RuleExecutionMetrics {
  RuleExecutionMetrics({
    required this.ruleId,
    required this.durationMs,
    required this.issuesFound,
    required this.hadError,
    this.errorMessage,
  });

  final String ruleId;
  final int durationMs;
  final int issuesFound;
  final bool hadError;
  final String? errorMessage;
}

/// Standard contract for AST diagnostic rules in flutter_dev_intelligence.
abstract class UiAstRuleContract {
  const UiAstRuleContract();

  /// Stable unique identifier for the rule (e.g. `ui.oversized-dimension`).
  String get id;

  /// Semantic version of the rule implementation (e.g. `1.0.0`).
  String get version => '1.0.0';

  /// Human-readable title of the diagnostic finding.
  String get title;

  /// Description of what the rule detects and why.
  String get description;

  /// Default diagnostic category.
  DiagnosticCategory get category => DiagnosticCategory.layout;

  /// Default diagnostic severity level.
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.medium;

  /// Default confidence score (0.0 to 1.0).
  double get defaultConfidence => 0.75;

  /// Rule detection capability classification.
  RuleCapability get capability => RuleCapability.staticAstHeuristic;

  /// Rule target applicability.
  RuleApplicability get applicability => RuleApplicability.flutterWidgetFiles;

  /// Evaluates an AST node with full analysis context.
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context);

  /// Helper factory for constructing a standardized [DiagnosticIssue].
  DiagnosticIssue createIssue(
    AstNode node,
    AstAnalysisContext context, {
    required String description,
    required String suggestion,
    DiagnosticSeverity? customSeverity,
    double? customConfidence,
    String? customId,
    String? customTitle,
    DiagnosticCategory? customCategory,
  }) {
    final loc = context.getLocation(node.offset);
    return DiagnosticIssue(
      id: customId ?? id,
      category: customCategory ?? category,
      severity: customSeverity ?? defaultSeverity,
      title: customTitle ?? title,
      description: description,
      filePath: context.filePath,
      line: loc.lineNumber,
      evidence: [
        EvidenceReference(
          type: EvidenceType.sourceFile,
          label: context.filePath,
          value: node.toSource(),
          metadata: <String, dynamic>{
            'column': loc.columnNumber,
            'analysis': 'static-ast',
            'ruleVersion': version,
          },
        ),
      ],
      suggestions: [
        FixSuggestion(
          action: suggestion,
          details: suggestion,
          riskLevel: FixRiskLevel.low,
          isSafeToAutomate: false,
          requiresUserConfirmation: true,
        ),
      ],
      confidence: customConfidence ?? defaultConfidence,
      source: 'static UI',
      limitation:
          'Static AST heuristic. Runtime layout verification is recommended.',
    );
  }
}
