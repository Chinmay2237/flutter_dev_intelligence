import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../core/models.dart';

/// Context provided to AST rules during traversal.
class UiAstContext {
  const UiAstContext({
    required this.filePath,
    required this.lineInfo,
    required this.scrollableStack,
    required this.parentWidgetNames,
    required this.enclosingMethodName,
  });

  final String filePath;
  final LineInfo lineInfo;
  final List<String> scrollableStack;
  final List<String> parentWidgetNames;
  final String? enclosingMethodName;

  bool get isInsideScrollable => scrollableStack.length > 1;
}

/// Abstract base class for AST UI analysis rules.
abstract class UiAstRule {
  const UiAstRule();

  String get id;
  String get title;
  DiagnosticCategory get category => DiagnosticCategory.layout;
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  double get defaultConfidence => 0.75;

  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context);

  DiagnosticIssue createIssue(
    AstNode node,
    UiAstContext context, {
    required String description,
    required String suggestion,
    DiagnosticSeverity? customSeverity,
    double? customConfidence,
    String? customId,
    String? customTitle,
    DiagnosticCategory? customCategory,
  }) {
    final location = context.lineInfo.getLocation(node.offset);
    return DiagnosticIssue(
      id: customId ?? id,
      category: customCategory ?? category,
      severity: customSeverity ?? severity,
      title: customTitle ?? title,
      description: description,
      filePath: context.filePath,
      line: location.lineNumber,
      evidence: [
        EvidenceReference(
          type: EvidenceType.sourceFile,
          label: context.filePath,
          value: node.toSource(),
          metadata: <String, dynamic>{
            'column': location.columnNumber,
            'analysis': 'static-ast',
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

String? _extractTypeName(AstNode node) {
  if (node is InstanceCreationExpression) {
    final raw = node.constructorName.type.toSource();
    return raw.contains('.') ? raw.split('.').last : raw;
  } else if (node is MethodInvocation) {
    final target = node.target;
    if (target != null) {
      final raw = target.toSource();
      return raw.contains('.') ? raw.split('.').last : raw;
    }
    return node.methodName.name;
  }
  return null;
}

/// Rule 1: Nested Scrollables
class UiNestedScrollableRule extends UiAstRule {
  const UiNestedScrollableRule();

  @override
  String get id => 'ui_nested_scrollable';

  @override
  String get title => 'Nested scrollable widget detected';

  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;

  @override
  double get defaultConfidence => 0.8;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = _extractTypeName(node);

    if (typeName != null &&
        _scrollableNames.contains(typeName) &&
        context.isInsideScrollable) {
      final parentScrollable = context.scrollableStack.first;

      // Check if inside CustomScrollView with Slivers
      if (parentScrollable == 'CustomScrollView' &&
          context.parentWidgetNames.any((w) => w.startsWith('Sliver'))) {
        return issues;
      }

      // Check physics parameter on node (e.g. NeverScrollableScrollPhysics)
      if (_hasNeverScrollablePhysics(node)) {
        return issues;
      }

      // Check if horizontal scrollable inside vertical scrollable
      if (_isHorizontalScrollDirection(node)) {
        issues.add(
          createIssue(
            node,
            context,
            customId: 'ui_nested_horizontal_scrollable',
            customTitle: 'Nested horizontal scrollable pattern detected',
            customSeverity: DiagnosticSeverity.info,
            customConfidence: 0.6,
            description:
                'Horizontal $typeName is nested inside vertical $parentScrollable. '
                'This is a common valid Flutter layout pattern (e.g., carousels, category rows) and is not automatically an error. '
                'Review only if gesture conflicts or layout issues occur.',
            suggestion:
                'Verify gesture boundaries for horizontal scrolling within vertical list if interaction issues are reported.',
          ),
        );
        return issues;
      }

      // Check if wrapped in bounded constraints (SizedBox, Container with height, Expanded, Flexible)
      final isBounded = context.parentWidgetNames.any(
        (name) => const {
          'SizedBox',
          'ConstrainedBox',
          'Container',
          'Expanded',
          'Flexible',
        }.contains(name),
      );

      final issueSeverity = isBounded
          ? DiagnosticSeverity.low
          : DiagnosticSeverity.medium;
      final issueConfidence = isBounded ? 0.65 : 0.8;

      issues.add(
        createIssue(
          node,
          context,
          customSeverity: issueSeverity,
          customConfidence: issueConfidence,
          description:
              'A $typeName is nested inside another scrollable widget ($parentScrollable).'
              '${isBounded ? " Wrapped in bounded container." : " May cause scrolling conflicts and unbounded layout errors."}',
          suggestion:
              'Consider combining scrollable content using CustomScrollView with Slivers, or setting explicit physics and constraints.',
        ),
      );
    }
    return issues;
  }

  static ArgumentList? _getArgumentList(AstNode node) {
    if (node is InstanceCreationExpression) {
      return node.argumentList;
    } else if (node is MethodInvocation) {
      return node.argumentList;
    }
    return null;
  }

  static bool _hasNeverScrollablePhysics(AstNode node) {
    final argumentList = _getArgumentList(node);
    if (argumentList != null) {
      for (final arg in argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'physics') {
          final src = arg.expression.toSource();
          if (src.contains('NeverScrollableScrollPhysics')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool _isHorizontalScrollDirection(AstNode node) {
    final argumentList = _getArgumentList(node);
    if (argumentList != null) {
      for (final arg in argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'scrollDirection') {
          final src = arg.expression.toSource();
          if (src.contains('Axis.horizontal') || src.contains('horizontal')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static const _scrollableNames = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SingleChildScrollView',
  };
}

/// Rule 2: Nested ShrinkWrap Usage
class UiNestedShrinkWrapRule extends UiAstRule {
  const UiNestedShrinkWrapRule();

  @override
  String get id => 'ui_nested_shrink_wrap';

  @override
  String get title => 'Nested shrink-wrapped scrollable detected';

  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.low;

  @override
  double get defaultConfidence => 0.75;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is NamedExpression &&
        node.name.label.name == 'shrinkWrap' &&
        node.expression.toSource() == 'true' &&
        context.isInsideScrollable) {
      issues.add(
        createIssue(
          node,
          context,
          description:
              'Nested scrollable widget uses shrinkWrap: true. ShrinkWrap forces layout measurement of all children, reducing performance.',
          suggestion:
              'Avoid shrinkWrap in large or dynamic lists. Use SliverList inside CustomScrollView instead.',
        ),
      );
    }
    return issues;
  }
}

/// Rule 3: Unconstrained Scrollable in Flex (Row/Column)
class UiUnconstrainedScrollableRule extends UiAstRule {
  const UiUnconstrainedScrollableRule();

  @override
  String get id => 'ui_unconstrained_scrollable';

  @override
  String get title => 'Unconstrained scrollable inside Row or Column';

  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.85;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = _extractTypeName(node);
    if (typeName != null && _unconstrainedScrollables.contains(typeName)) {
      final parentWidget = context.parentWidgetNames.isNotEmpty
          ? context.parentWidgetNames.last
          : null;
      if (parentWidget != null && _flexContainers.contains(parentWidget)) {
        issues.add(
          createIssue(
            node,
            context,
            description:
                '$typeName is placed directly inside a $parentWidget without an Expanded or Flexible wrapper. '
                'This will cause a runtime layout overflow exception.',
            suggestion:
                'Wrap the $typeName in an Expanded or Flexible widget, or specify explicit constraints.',
          ),
        );
      }
    }
    return issues;
  }

  static const _unconstrainedScrollables = <String>{'ListView', 'GridView'};
  static const _flexContainers = <String>{'Column', 'Row', 'Flex'};
}

/// Rule 4: Expanded / Flexible Misuse
class UiExpandedMisuseRule extends UiAstRule {
  const UiExpandedMisuseRule();

  @override
  String get id => 'ui_expanded_misuse';

  @override
  String get title => 'Expanded or Flexible used outside Row, Column, or Flex';

  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.9;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = _extractTypeName(node);
    if (typeName == 'Expanded' || typeName == 'Flexible') {
      final parentWidget = context.parentWidgetNames.isNotEmpty
          ? context.parentWidgetNames.last
          : null;
      if (parentWidget != null && !_flexContainers.contains(parentWidget)) {
        issues.add(
          createIssue(
            node,
            context,
            description:
                '$typeName widget is placed inside $parentWidget. $typeName can only be used as a direct child of Row, Column, or Flex.',
            suggestion:
                'Remove $typeName or place it inside a Column, Row, or Flex parent.',
          ),
        );
      }
    }
    return issues;
  }

  static const _flexContainers = <String>{'Column', 'Row', 'Flex'};
}

/// Rule 5: Oversized Hardcoded Dimensions
class UiOversizedDimensionRule extends UiAstRule {
  const UiOversizedDimensionRule();

  @override
  String get id => 'ui_oversized_dimension';

  @override
  String get title => 'Oversized hardcoded layout dimension';

  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.low;

  @override
  double get defaultConfidence => 0.7;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is NamedExpression) {
      final name = node.name.label.name;
      if ((name == 'width' || name == 'height') &&
          node.expression is IntegerLiteral) {
        final value = (node.expression as IntegerLiteral).value;
        if (value != null && value > 1000) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'Hardcoded $name of $value logical pixels exceeds standard screen dimensions.',
              suggestion:
                  'Use MediaQuery, LayoutBuilder, or flexible constraints instead of large fixed pixel dimensions.',
            ),
          );
        }
      }
    }
    return issues;
  }
}

/// Rule 6: Nested Scaffold or MaterialApp
class UiNestedScaffoldRule extends UiAstRule {
  const UiNestedScaffoldRule();

  @override
  String get id => 'ui_nested_scaffold';

  @override
  String get title => 'Nested Scaffold or MaterialApp detected';

  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;

  @override
  double get defaultConfidence => 0.8;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = _extractTypeName(node);
    if (typeName == 'Scaffold' || typeName == 'MaterialApp') {
      if (context.parentWidgetNames.contains(typeName)) {
        issues.add(
          createIssue(
            node,
            context,
            description:
                'A $typeName is nested inside another $typeName. '
                'Multiple nested Scaffolds or MaterialApps can break navigation, theme inheritance, and snackbars.',
            suggestion:
                'Use a single top-level $typeName or restructure widget tree routing.',
          ),
        );
      }
    }
    return issues;
  }
}

/// Rule 7: Suspicious setState in build method
class UiSuspiciousSetStateRule extends UiAstRule {
  const UiSuspiciousSetStateRule();

  @override
  String get id => 'ui_suspicious_setstate';

  @override
  String get title => 'setState called directly inside build method';

  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.95;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, UiAstContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is MethodInvocation && node.methodName.name == 'setState') {
      if (context.enclosingMethodName == 'build') {
        if (!_isInsideCallbackOrClosure(node)) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'setState() was invoked directly inside the widget build() method. '
                  'This causes infinite build loops and immediate runtime crashes.',
              suggestion:
                  'Move setState() calls into event handlers (onTap, onPressed) or lifecycle hooks.',
            ),
          );
        }
      }
    }
    return issues;
  }

  static bool _isInsideCallbackOrClosure(MethodInvocation node) {
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is MethodDeclaration) {
        return false;
      }
      if (parent is FunctionExpression || parent is FunctionDeclaration) {
        return true;
      }
      parent = parent.parent;
    }
    return false;
  }
}

/// Registry of UI AST rules and orchestrator for AST visits.
class UiAstRuleRegistry {
  const UiAstRuleRegistry({
    this.rules = const <UiAstRule>[
      UiNestedScrollableRule(),
      UiNestedShrinkWrapRule(),
      UiUnconstrainedScrollableRule(),
      UiExpandedMisuseRule(),
      UiOversizedDimensionRule(),
      UiNestedScaffoldRule(),
      UiSuspiciousSetStateRule(),
    ],
  });

  final List<UiAstRule> rules;

  List<DiagnosticIssue> analyze(CompilationUnit unit, String filePath) {
    final visitor = _UiAstVisitor(rules, filePath, unit.lineInfo);
    unit.accept(visitor);
    return visitor.issues;
  }
}

class _UiAstVisitor extends RecursiveAstVisitor<void> {
  _UiAstVisitor(this.rules, this.filePath, this.lineInfo);

  final List<UiAstRule> rules;
  final String filePath;
  final LineInfo lineInfo;
  final List<DiagnosticIssue> issues = <DiagnosticIssue>[];
  final Set<String> _issueKeys = <String>{};

  final List<String> _scrollableStack = <String>[];
  final List<String> _parentWidgetNames = <String>[];
  String? _enclosingMethodName;

  static const _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SingleChildScrollView',
  };

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final previousMethod = _enclosingMethodName;
    _enclosingMethodName = node.name.lexeme;
    try {
      super.visitMethodDeclaration(node);
    } finally {
      _enclosingMethodName = previousMethod;
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final previousMethod = _enclosingMethodName;
    _enclosingMethodName = node.name.lexeme;
    try {
      super.visitFunctionDeclaration(node);
    } finally {
      _enclosingMethodName = previousMethod;
    }
  }

  void _visitWidgetNode(AstNode node, void Function() superVisit) {
    final typeName = _extractTypeName(node);
    if (typeName == null) {
      superVisit();
      return;
    }
    final isScrollable = _scrollableTypes.contains(typeName);

    if (isScrollable) {
      _scrollableStack.add(typeName);
    }

    final context = UiAstContext(
      filePath: filePath,
      lineInfo: lineInfo,
      scrollableStack: List<String>.from(_scrollableStack),
      parentWidgetNames: List<String>.from(_parentWidgetNames),
      enclosingMethodName: _enclosingMethodName,
    );

    _runRulesOnNode(node, context);

    _parentWidgetNames.add(typeName);
    try {
      superVisit();
    } finally {
      _parentWidgetNames.removeLast();
      if (isScrollable) {
        _scrollableStack.removeLast();
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _visitWidgetNode(node, () => super.visitInstanceCreationExpression(node));
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _visitWidgetNode(node, () => super.visitMethodInvocation(node));
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final context = UiAstContext(
      filePath: filePath,
      lineInfo: lineInfo,
      scrollableStack: _scrollableStack,
      parentWidgetNames: _parentWidgetNames,
      enclosingMethodName: _enclosingMethodName,
    );

    _runRulesOnNode(node, context);
    super.visitNamedExpression(node);
  }

  void _runRulesOnNode(AstNode node, UiAstContext context) {
    for (final rule in rules) {
      final detected = rule.checkNode(node, context);
      for (final issue in detected) {
        final key =
            '${issue.id}:${issue.line}:${issue.evidence.firstOrNull?.metadata?['column'] ?? 0}';
        if (_issueKeys.add(key)) {
          issues.add(issue);
        }
      }
    }
  }
}
