import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../core/config.dart';
import '../core/models.dart';
import 'ast_analysis_context.dart';
import 'ui_ast_rule.dart';
import 'ui_ast_rule_contract.dart';

/// Registry holding active AST diagnostic rules.
class UiAstRuleRegistry {
  const UiAstRuleRegistry({
    this.rules = const <UiAstRuleContract>[
      UiNestedScrollableRule(),
      UiNestedShrinkWrapRule(),
      UiUnconstrainedScrollableRule(),
      UiExpandedMisuseRule(),
      UiPositionedMisuseRule(),
      UiOversizedDimensionRule(),
      UiUnboundedDimensionRule(),
      UiNestedScaffoldRule(),
      UiSuspiciousSetStateRule(),
      UiBuildExpensiveOperationRule(),
      UiEagerLargeListRule(),
      UiUnlabeledInteractiveRule(),
      UiUnlabeledFormFieldRule(),
      UiUndisposedControllerRule(),
      UiUndisposedSubscriptionRule(),
      UiAsyncLifecycleSafetyRule(),
      UiPerformanceSuggestionsRule(),
    ],
  });

  final List<UiAstRuleContract> rules;

  /// Returns rules sorted deterministically by rule ID.
  List<UiAstRuleContract> getSortedRules() {
    final copy = List<UiAstRuleContract>.from(rules);
    copy.sort((a, b) => a.id.compareTo(b.id));
    return copy;
  }
}

/// Result of executing AST rules over a single compilation unit.
class RuleExecutionResult {
  const RuleExecutionResult({
    required this.issues,
    required this.metrics,
    required this.ruleErrors,
  });

  final List<DiagnosticIssue> issues;
  final List<RuleExecutionMetrics> metrics;
  final List<String> ruleErrors;
}

/// Executes registered AST rules over an AST compilation unit with error isolation.
class RuleExecutor {
  const RuleExecutor();

  /// Traverses [unit] and executes active rules registered in [registry].
  static RuleExecutionResult execute({
    required CompilationUnit unit,
    required String filePath,
    required LineInfo lineInfo,
    UiAstRuleRegistry registry = const UiAstRuleRegistry(),
    ProjectConfig config = const ProjectConfig(),
  }) {
    final activeRules = registry.getSortedRules().where((rule) {
      if (config.disabledRules.contains(rule.id)) return false;
      if (config.enabledRules != null &&
          config.enabledRules!.isNotEmpty &&
          !config.enabledRules!.contains(rule.id)) {
        return false;
      }
      return true;
    }).toList();

    final issues = <DiagnosticIssue>[];
    final metrics = <RuleExecutionMetrics>[];
    final ruleErrors = <String>[];

    final ruleTiming = <String, int>{};
    final ruleIssues = <String, int>{};
    final ruleFailures = <String, String>{};

    final visitor = AstContextVisitor(
      filePath: filePath,
      lineInfo: lineInfo,
      onNodeVisited: (node, context) {
        for (final rule in activeRules) {
          final stopwatch = Stopwatch()..start();
          try {
            final found = rule.checkNode(node, context);
            stopwatch.stop();

            ruleTiming[rule.id] =
                (ruleTiming[rule.id] ?? 0) + stopwatch.elapsedMilliseconds;
            if (found.isNotEmpty) {
              ruleIssues[rule.id] = (ruleIssues[rule.id] ?? 0) + found.length;
              issues.addAll(found);
            }
          } catch (e) {
            stopwatch.stop();
            final errorMsg =
                'Rule ${rule.id} failed on node at offset ${node.offset} in $filePath: $e';
            ruleFailures[rule.id] = errorMsg;
            ruleErrors.add(errorMsg);

            // Add safe, isolated diagnostic issue for rule failure
            issues.add(
              DiagnosticIssue(
                id: 'rule_execution_failure',
                category: DiagnosticCategory.architecture,
                severity: DiagnosticSeverity.low,
                title: 'AST rule execution failure',
                description:
                    'Rule ${rule.id} encountered an error during analysis.',
                filePath: filePath,
                line: lineInfo.getLocation(node.offset).lineNumber,
                evidence: [
                  EvidenceReference(
                    type: EvidenceType.configuration,
                    label: rule.id,
                    value: errorMsg,
                  ),
                ],
                suggestions: const [],
                confidence: 1.0,
                source: 'engine',
              ),
            );
          }
        }
      },
    );

    unit.accept(visitor);

    for (final rule in activeRules) {
      metrics.add(
        RuleExecutionMetrics(
          ruleId: rule.id,
          durationMs: ruleTiming[rule.id] ?? 0,
          issuesFound: ruleIssues[rule.id] ?? 0,
          hadError: ruleFailures.containsKey(rule.id),
          errorMessage: ruleFailures[rule.id],
        ),
      );
    }

    // Sort issues deterministically by filePath, line, and issue ID
    issues.sort((a, b) {
      final pathComp = (a.filePath ?? '').compareTo(b.filePath ?? '');
      if (pathComp != 0) return pathComp;
      final lineComp = (a.line ?? 0).compareTo(b.line ?? 0);
      if (lineComp != 0) return lineComp;
      return a.id.compareTo(b.id);
    });

    return RuleExecutionResult(
      issues: issues,
      metrics: metrics,
      ruleErrors: ruleErrors,
    );
  }
}
