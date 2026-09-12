import 'package:analyzer/dart/ast/ast.dart';

import '../core/models.dart';
import 'ast_analysis_context.dart';
import 'ui_ast_rule_contract.dart';
import 'widget_taxonomy.dart';

/// Legacy alias for backward compatibility.
abstract class UiAstRule extends UiAstRuleContract {
  const UiAstRule();
}

/// Helper functions for analyzing AST nodes.
bool _hasNeverScrollablePhysics(AstNode node) {
  final args = AstAnalysisContext.getNamedArguments(node);
  final physics = args['physics'];
  if (physics != null) {
    final src = physics.toSource();
    return src.contains('NeverScrollableScrollPhysics');
  }
  return false;
}

bool _isHorizontalScrollDirection(AstNode node) {
  final args = AstAnalysisContext.getNamedArguments(node);
  final dir = args['scrollDirection'];
  if (dir != null) {
    final src = dir.toSource();
    return src.contains('Axis.horizontal') || src.contains('horizontal');
  }
  return false;
}

/// Rule 1: Nested Scrollables
class UiNestedScrollableRule extends UiAstRuleContract {
  const UiNestedScrollableRule();

  @override
  String get id => 'ui.nested-scrollable';

  @override
  String get title => 'Nested scrollable widget detected';

  @override
  String get description =>
      'Detects same-axis nested scrollable widgets without NeverScrollableScrollPhysics or explicit constraints.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.medium;

  @override
  double get defaultConfidence => 0.8;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);

    if (typeName != null &&
        WidgetTaxonomy.isScrollable(typeName) &&
        context.widgetStack.length > 1) {
      AstNode? parentWidgetNode;
      String? parentWidget;
      for (var i = context.widgetStack.length - 2; i >= 0; i--) {
        final wName = AstAnalysisContext.extractWidgetName(
          context.widgetStack[i],
        );
        if (wName != null && WidgetTaxonomy.isScrollable(wName)) {
          parentWidgetNode = context.widgetStack[i];
          parentWidget = wName;
          break;
        }
      }

      if (parentWidget == null || parentWidgetNode == null) return issues;

      // CustomScrollView with Slivers
      if (parentWidget == 'CustomScrollView' &&
          context.hasAncestorTaxonomyCategory(WidgetTaxonomyCategory.sliver)) {
        return issues;
      }

      // Check physics parameter on child node
      if (_hasNeverScrollablePhysics(node)) {
        return issues;
      }

      // Horizontal scrollable in vertical container (or vice-versa)
      final isChildHorizontal = _isHorizontalScrollDirection(node);
      final isParentHorizontal = _isHorizontalScrollDirection(parentWidgetNode);

      if (isChildHorizontal != isParentHorizontal) {
        issues.add(
          createIssue(
            node,
            context,
            customId: 'ui.nested-horizontal-scrollable',
            customTitle: 'Nested cross-axis scrollable pattern detected',
            customSeverity: DiagnosticSeverity.info,
            customConfidence: 0.6,
            description:
                'Cross-axis $typeName is nested inside $parentWidget. '
                'This is a common valid Flutter layout pattern (e.g., carousels, category rows).',
            suggestion:
                'Verify gesture boundaries for horizontal scrolling within vertical list if touch conflicts occur.',
          ),
        );
        return issues;
      }

      // Unknown custom parent widget reduces confidence
      final parentClassification = WidgetTaxonomy.classify(parentWidget);
      final isUnknownParent = parentClassification.isUnknown;

      final isBounded = context.hasAncestorTaxonomyCategory(
        WidgetTaxonomyCategory.constraintProvider,
      );
      final issueSeverity = isBounded
          ? DiagnosticSeverity.low
          : DiagnosticSeverity.medium;
      final issueConfidence = isUnknownParent ? 0.5 : (isBounded ? 0.65 : 0.8);

      issues.add(
        createIssue(
          node,
          context,
          customSeverity: issueSeverity,
          customConfidence: issueConfidence,
          description:
              'A $typeName is nested inside another scrollable widget ($parentWidget).'
              '${isBounded ? " Wrapped in bounded container." : " May cause scrolling conflicts and unbounded layout errors."}',
          suggestion:
              'Consider combining scrollable content using CustomScrollView with Slivers, or setting physics: NeverScrollableScrollPhysics().',
        ),
      );
    }
    return issues;
  }
}

/// Rule 2: Nested ShrinkWrap Usage
class UiNestedShrinkWrapRule extends UiAstRuleContract {
  const UiNestedShrinkWrapRule();

  @override
  String get id => 'ui.nested-shrink-wrap';

  @override
  String get title => 'Nested shrink-wrapped scrollable detected';

  @override
  String get description =>
      'Detects shrinkWrap: true inside scrollable containers.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.low;

  @override
  double get defaultConfidence => 0.75;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is NamedExpression &&
        node.name.label.name == 'shrinkWrap' &&
        node.expression.toSource() == 'true' &&
        context.widgetStack.length > 1) {
      final parentExpr =
          context.findAncestor<InstanceCreationExpression>() ??
          context.findAncestor<MethodInvocation>();

      final hasNeverScrollable =
          parentExpr != null && _hasNeverScrollablePhysics(parentExpr);

      issues.add(
        createIssue(
          node,
          context,
          customSeverity: hasNeverScrollable
              ? DiagnosticSeverity.info
              : DiagnosticSeverity.low,
          customConfidence: hasNeverScrollable ? 0.5 : 0.75,
          description:
              'Nested scrollable widget uses shrinkWrap: true.'
              '${hasNeverScrollable ? " Recognized with NeverScrollableScrollPhysics mitigation." : " ShrinkWrap forces layout measurement of all children, reducing performance."}',
          suggestion:
              'Avoid shrinkWrap in large or dynamic lists. Use SliverList inside CustomScrollView instead.',
        ),
      );
    }
    return issues;
  }
}

/// Rule 3: Unconstrained Scrollable in Flex (Row/Column)
class UiUnconstrainedScrollableRule extends UiAstRuleContract {
  const UiUnconstrainedScrollableRule();

  @override
  String get id => 'ui.unconstrained-scrollable';

  @override
  String get title => 'Unconstrained scrollable inside Row or Column';

  @override
  String get description =>
      'Detects scrollable widgets directly placed inside flex containers without Expanded, Flexible, or explicit constraints.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.85;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);

    if (typeName != null && WidgetTaxonomy.isScrollable(typeName)) {
      if (context.widgetStack.length >= 2) {
        final parentWidgetNode =
            context.widgetStack[context.widgetStack.length - 2];
        final parentWidget = AstAnalysisContext.extractWidgetName(
          parentWidgetNode,
        );

        if (parentWidget != null &&
            WidgetTaxonomy.isFlexContainer(parentWidget)) {
          // Check if parent widget is Expanded/Flexible
          final immediateParentName = AstAnalysisContext.extractWidgetName(
            context.widgetStack.last,
          );

          if (immediateParentName == 'Expanded' ||
              immediateParentName == 'Flexible' ||
              WidgetTaxonomy.isConstraintProvider(immediateParentName ?? '')) {
            return issues;
          }

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
    }
    return issues;
  }
}

/// Rule 4: Expanded / Flexible Misuse
class UiExpandedMisuseRule extends UiAstRuleContract {
  const UiExpandedMisuseRule();

  @override
  String get id => 'ui.expanded-misuse';

  @override
  String get title =>
      'Expanded, Flexible, or Spacer used outside Row, Column, or Flex';

  @override
  String get description =>
      'Detects Expanded, Flexible, or Spacer widgets placed outside flex containers.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.9;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);

    if (typeName == 'Expanded' ||
        typeName == 'Flexible' ||
        typeName == 'Spacer') {
      if (context.widgetStack.length >= 2) {
        final parentWidget = AstAnalysisContext.extractWidgetName(
          context.widgetStack[context.widgetStack.length - 2],
        );
        if (parentWidget != null &&
            !WidgetTaxonomy.isFlexContainer(parentWidget)) {
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
    }
    return issues;
  }
}

/// Rule 5: Positioned Misuse outside Stack
class UiPositionedMisuseRule extends UiAstRuleContract {
  const UiPositionedMisuseRule();

  @override
  String get id => 'ui.positioned-misuse';

  @override
  String get title => 'Positioned widget used outside Stack';

  @override
  String get description =>
      'Detects Positioned or Positioned.fill widgets placed outside a Stack ancestor.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.9;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);

    if (typeName == 'Positioned') {
      final hasStackParent = context.widgetStack.any(
        (w) => AstAnalysisContext.extractWidgetName(w) == 'Stack',
      );

      if (!hasStackParent) {
        issues.add(
          createIssue(
            node,
            context,
            description:
                'Positioned widget is placed outside a Stack. Positioned must be a descendant of a Stack.',
            suggestion:
                'Wrap Positioned inside a Stack or remove the Positioned widget.',
          ),
        );
      }
    }
    return issues;
  }
}

/// Rule 6: Oversized Hardcoded Dimensions
class UiOversizedDimensionRule extends UiAstRuleContract {
  const UiOversizedDimensionRule();

  @override
  String get id => 'ui.oversized-dimension';

  @override
  String get title => 'Oversized hardcoded layout dimension';

  @override
  String get description =>
      'Detects hardcoded fixed pixel dimensions exceeding 1000 pixels.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.low;

  @override
  double get defaultConfidence => 0.7;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
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

/// Rule 7: Unbounded Dimension Misuse
class UiUnboundedDimensionRule extends UiAstRuleContract {
  const UiUnboundedDimensionRule();

  @override
  String get id => 'ui.unbounded-dimension';

  @override
  String get title =>
      'double.infinity used inside unconstrained flex container';

  @override
  String get description =>
      'Detects double.infinity used in unbounded flex directions (e.g. height in Column).';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.85;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is NamedExpression) {
      final propName = node.name.label.name;
      final src = node.expression.toSource();

      if (src == 'double.infinity') {
        if (propName == 'height' &&
            _hasUnconstrainedFlexAncestor(
              context.widgetStack,
              flexContainer: 'Column',
            )) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'double.infinity height is used inside a Column. Column has unconstrained vertical height, leading to layout overflow.',
              suggestion:
                  'Use Expanded, Flexible, or explicit height constraints instead of double.infinity inside Column.',
            ),
          );
        } else if (propName == 'width' &&
            _hasUnconstrainedFlexAncestor(
              context.widgetStack,
              flexContainer: 'Row',
            )) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'double.infinity width is used inside a Row. Row has unconstrained horizontal width, leading to layout overflow.',
              suggestion:
                  'Use Expanded, Flexible, or explicit width constraints instead of double.infinity inside Row.',
            ),
          );
        }
      }
    }
    return issues;
  }

  bool _hasUnconstrainedFlexAncestor(
    List<AstNode> stack, {
    required String flexContainer,
  }) {
    for (var i = stack.length - 1; i >= 0; i--) {
      final name = AstAnalysisContext.extractWidgetName(stack[i]);
      if (name == 'Expanded' || name == 'Flexible') {
        return false;
      }
      if (name == flexContainer) {
        return true;
      }
    }
    return false;
  }
}

/// Rule 8: Nested Scaffold or MaterialApp
class UiNestedScaffoldRule extends UiAstRuleContract {
  const UiNestedScaffoldRule();

  @override
  String get id => 'ui.nested-scaffold';

  @override
  String get title => 'Nested Scaffold or MaterialApp detected';

  @override
  String get description => 'Detects nested Scaffolds or MaterialApps.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.medium;

  @override
  double get defaultConfidence => 0.8;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);
    if (typeName == 'Scaffold' || typeName == 'MaterialApp') {
      final hasParentScaffold = context.widgetStack
          .take(context.widgetStack.length - 1)
          .any((w) => AstAnalysisContext.extractWidgetName(w) == typeName);

      if (hasParentScaffold) {
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

/// Rule 9: Suspicious setState in build method
class UiSuspiciousSetStateRule extends UiAstRuleContract {
  const UiSuspiciousSetStateRule();

  @override
  String get id => 'ui.build.setstate';

  @override
  String get title => 'setState called directly inside build method';

  @override
  String get description =>
      'Detects setState() calls invoked directly in build() outside callbacks.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.95;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is MethodInvocation && node.methodName.name == 'setState') {
      if (context.isInBuildMethod && !context.isInCallback) {
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
    return issues;
  }
}

/// Rule 10: Heavy/Expensive Operations inside build()
class UiBuildExpensiveOperationRule extends UiAstRuleContract {
  const UiBuildExpensiveOperationRule();

  @override
  String get id => 'ui.build.expensive-operation';

  @override
  String get title => 'Heavy operation or state initialization inside build()';

  @override
  String get description =>
      'Detects network calls, DB queries, JSON parsing, controller instantiations, or heavy sorting directly inside build().';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.medium;

  @override
  double get defaultConfidence => 0.8;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    if (context.isInBuildMethod && !context.isInCallback) {
      if (node is MethodInvocation) {
        final methodName = node.methodName.name;
        final targetSrc = node.target?.toSource() ?? '';

        // Network calls
        if ((methodName == 'get' || methodName == 'post') &&
            (targetSrc.startsWith('http') ||
                targetSrc.contains('dio') ||
                targetSrc.contains('Client'))) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'Network call ($targetSrc.$methodName) invoked directly inside build(). '
                  'This will re-trigger network requests on every frame rebuild.',
              suggestion:
                  'Move network requests to initState() or a state management controller.',
            ),
          );
        }

        // JSON parsing
        if (methodName == 'jsonDecode' ||
            (methodName == 'decode' && targetSrc == 'json')) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'JSON parsing ($methodName) invoked directly inside build(). '
                  'Parsing JSON on every frame drops frames during animations.',
              suggestion:
                  'Parse JSON payloads asynchronously in background tasks or data repositories.',
            ),
          );
        }

        // Database queries
        if (methodName == 'rawQuery' ||
            methodName == 'query' ||
            targetSrc.contains('database') ||
            targetSrc.contains('isar') ||
            targetSrc.contains('hive')) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'Database query operation (${node.toSource()}) invoked directly inside build(). '
                  'Database I/O inside build() causes severe UI stutter and frame drops.',
              suggestion:
                  'Execute database queries in state controllers or FutureBuilder/StreamBuilder initializers.',
            ),
          );
        }

        // Future / Stream creation in build
        if ((targetSrc == 'Future' &&
                (methodName == 'delayed' ||
                    methodName == 'value' ||
                    methodName == 'microtask')) ||
            (targetSrc == 'Stream' &&
                (methodName == 'periodic' ||
                    methodName == 'fromIterable' ||
                    methodName == 'fromFuture'))) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'Future/Stream creation ($targetSrc.$methodName) invoked directly inside build(). '
                  'Creating futures or streams directly in build() causes infinite re-triggers and listener leaks when used in FutureBuilder/StreamBuilder.',
              suggestion:
                  'Instantiate Futures/Streams in initState() or store them in State fields.',
            ),
          );
        }

        // Heavy sorting in build
        if (methodName == 'sort') {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'Synchronous sorting (.sort()) executed directly inside build(). '
                  'Sorting collections during build method execution causes avoidable CPU churn on every frame.',
              suggestion:
                  'Pre-sort collections in state management logic or view models before passing to widgets.',
            ),
          );
        }
      } else if (node is InstanceCreationExpression) {
        final typeName = AstAnalysisContext.extractWidgetName(node);
        if (typeName == 'TextEditingController' ||
            typeName == 'AnimationController' ||
            typeName == 'ScrollController' ||
            typeName == 'TabController') {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  'Controller ($typeName) instantiated directly inside build(). '
                  'The controller will be recreated on every build, losing state and leaking listeners.',
              suggestion:
                  'Instantiate controllers in State.initState() and dispose them in State.dispose().',
            ),
          );
        }
      }
    }
    return issues;
  }
}

/// Rule 14: Undisposed Controller/Notifier in State
class UiUndisposedControllerRule extends UiAstRuleContract {
  const UiUndisposedControllerRule();

  @override
  String get id => 'ui.lifecycle.undisposed-controller';

  @override
  String get title => 'Undisposed controller or notifier in State class';

  @override
  String get description =>
      'Detects AnimationController, ScrollController, TextEditingController, FocusNode, or Notifiers declared in State without dispose().';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.85;

  static const Set<String> targetControllers = <String>{
    'AnimationController',
    'ScrollController',
    'TextEditingController',
    'FocusNode',
    'PageController',
    'TabController',
    'StreamController',
    'ValueNotifier',
    'ChangeNotifier',
  };

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is ClassDeclaration && _isStateClass(node)) {
      final controllerFields = <String, FieldDeclaration>{};
      for (final member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          for (final variable in member.fields.variables) {
            final name = variable.name.lexeme;
            final typeName = member.fields.type?.toSource();
            final initSrc = variable.initializer?.toSource() ?? '';

            final isTargetType =
                (typeName != null &&
                    targetControllers.any((c) => typeName.contains(c))) ||
                targetControllers.any((c) => initSrc.contains(c));

            final isFromWidget = initSrc.contains('widget.');

            if (isTargetType && !isFromWidget) {
              controllerFields[name] = member;
            }
          }
        }
      }

      if (controllerFields.isEmpty) return issues;

      MethodDeclaration? disposeMethod;
      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      final disposeSource = disposeMethod?.body.toSource() ?? '';
      final helperSources = node.members
          .whereType<MethodDeclaration>()
          .map((m) => m.body.toSource())
          .join('\n');
      final combinedDisposalSource = '$disposeSource\n$helperSources';

      controllerFields.forEach((fieldName, fieldDecl) {
        final isDisposed =
            combinedDisposalSource.contains('$fieldName.dispose') ||
            combinedDisposalSource.contains('dispose($fieldName)');

        if (!isDisposed) {
          issues.add(
            createIssue(
              fieldDecl,
              context,
              description:
                  'Controller or notifier field "$fieldName" created in ${node.name.lexeme} is never disposed in State.dispose(). '
                  'Failing to dispose controllers causes memory leaks, uncancelled tickers, and background callbacks.',
              suggestion:
                  'Override dispose() in ${node.name.lexeme} and call $fieldName.dispose() before super.dispose().',
            ),
          );
        }
      });
    }
    return issues;
  }

  bool _isStateClass(ClassDeclaration decl) {
    final extendsClause = decl.extendsClause?.superclass.toSource() ?? '';
    return extendsClause.startsWith('State') ||
        decl.name.lexeme.endsWith('State');
  }
}

/// Rule 15: Undisposed StreamSubscription, Timer, or Observer in State
class UiUndisposedSubscriptionRule extends UiAstRuleContract {
  const UiUndisposedSubscriptionRule();

  @override
  String get id => 'ui.lifecycle.undisposed-subscription';

  @override
  String get title =>
      'Undisposed StreamSubscription, Timer, or Observer in State class';

  @override
  String get description =>
      'Detects StreamSubscription, Timer, or WidgetsBindingObserver registered in State without cancellation or removal in dispose().';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.high;

  @override
  double get defaultConfidence => 0.8;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    if (node is ClassDeclaration && _isStateClass(node)) {
      MethodDeclaration? disposeMethod;
      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }
      final disposeSource = disposeMethod?.body.toSource() ?? '';
      final helperSources = node.members
          .whereType<MethodDeclaration>()
          .map((m) => m.body.toSource())
          .join('\n');
      final combinedDisposalSource = '$disposeSource\n$helperSources';

      for (final member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          for (final variable in member.fields.variables) {
            final name = variable.name.lexeme;
            final typeName = member.fields.type?.toSource() ?? '';
            final initSrc = variable.initializer?.toSource() ?? '';

            final isSubscriptionOrTimer =
                typeName.contains('StreamSubscription') ||
                typeName.contains('Timer') ||
                initSrc.contains('StreamSubscription') ||
                initSrc.contains('Timer.periodic') ||
                initSrc.contains('.listen(');

            final isFromWidget = initSrc.contains('widget.');

            if (isSubscriptionOrTimer && !isFromWidget) {
              final isCancelled =
                  combinedDisposalSource.contains('$name.cancel') ||
                  combinedDisposalSource.contains('cancel($name)');

              if (!isCancelled) {
                issues.add(
                  createIssue(
                    member,
                    context,
                    description:
                        'StreamSubscription or Timer "$name" created in ${node.name.lexeme} is never cancelled in State.dispose(). '
                        'Uncancelled subscriptions or timers continue executing after widget unmount, causing state corruption and memory leaks.',
                    suggestion:
                        'Call $name?.cancel() inside State.dispose() before super.dispose().',
                  ),
                );
              }
            }
          }
        }
      }

      final classSource = node.toSource();
      if (classSource.contains('addObserver(')) {
        final hasRemoveObserver = combinedDisposalSource.contains(
          'removeObserver(',
        );
        if (!hasRemoveObserver) {
          issues.add(
            createIssue(
              node,
              context,
              description:
                  '${node.name.lexeme} registers an observer via addObserver() but does not unregister it with removeObserver() in dispose(). '
                  'Dangling observers cause memory leaks and runtime exceptions when system events trigger.',
              suggestion:
                  'Add WidgetsBinding.instance.removeObserver(this) inside State.dispose().',
            ),
          );
        }
      }
    }
    return issues;
  }

  bool _isStateClass(ClassDeclaration decl) {
    final extendsClause = decl.extendsClause?.superclass.toSource() ?? '';
    return extendsClause.startsWith('State') ||
        decl.name.lexeme.endsWith('State');
  }
}

/// Rule 16: Async Lifecycle Safety (BuildContext & setState after await)
class UiAsyncLifecycleSafetyRule extends UiAstRuleContract {
  const UiAsyncLifecycleSafetyRule();

  @override
  String get id => 'ui.async.use-build-context';

  @override
  String get title => 'Unsafe BuildContext or setState usage after async gap';

  @override
  String get description =>
      'Detects BuildContext or setState() used across an await boundary without checking mounted status.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.medium;

  @override
  double get defaultConfidence => 0.75;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];

    if (node is MethodDeclaration || node is FunctionExpression) {
      final body = node is MethodDeclaration
          ? node.body
          : (node as FunctionExpression).body;

      if (body is BlockFunctionBody) {
        final statements = body.block.statements;
        for (var i = 0; i < statements.length; i++) {
          final stmt = statements[i];
          if (_containsAwait(stmt)) {
            for (var j = i + 1; j < statements.length; j++) {
              final subsequentStmt = statements[j];
              final stmtSrc = subsequentStmt.toSource();

              if (_isMountedCheck(subsequentStmt)) {
                break;
              }

              if (context.currentClass != null &&
                  _isStateClassName(context.currentClass!.name.lexeme) &&
                  stmtSrc.contains('setState(')) {
                issues.add(
                  createIssue(
                    subsequentStmt,
                    context,
                    customId: 'ui.async.setstate-unmounted',
                    customTitle:
                        'setState() called after await without mounted check',
                    customSeverity: DiagnosticSeverity.medium,
                    customConfidence: 0.8,
                    description:
                        'setState() is invoked after an async gap (await) without checking if the widget is still mounted. '
                        'If the widget is unmounted while the async operation is pending, calling setState() throws a runtime error.',
                    suggestion:
                        'Add "if (!mounted) return;" or "if (mounted) { setState(...); }" immediately after the await statement.',
                  ),
                );
                break;
              }

              if (stmtSrc.contains('context') &&
                  _usesBuildContextInFrameworkCall(stmtSrc)) {
                issues.add(
                  createIssue(
                    subsequentStmt,
                    context,
                    customId: 'ui.async.use-build-context',
                    customTitle:
                        'BuildContext used across async gap without mounted check',
                    customSeverity: DiagnosticSeverity.low,
                    customConfidence: 0.7,
                    description:
                        'BuildContext is used after an async gap (await) without verifying context.mounted. '
                        'Using an invalid context after unmounting can cause runtime exceptions and stale UI navigation.',
                    suggestion:
                        'Add "if (!context.mounted) return;" before using context after an await.',
                  ),
                );
                break;
              }
            }
          }
        }
      }
    }
    return issues;
  }

  bool _containsAwait(Statement stmt) {
    return stmt.toSource().contains('await ');
  }

  bool _isMountedCheck(Statement stmt) {
    final src = stmt.toSource();
    return src.contains('mounted') || src.contains('context.mounted');
  }

  bool _usesBuildContextInFrameworkCall(String src) {
    return src.contains('Navigator.of(') ||
        src.contains('ScaffoldMessenger.of(') ||
        src.contains('Theme.of(') ||
        src.contains('MediaQuery.of(') ||
        src.contains('Provider.of(');
  }

  bool _isStateClassName(String name) {
    return name.endsWith('State');
  }
}

/// Rule 17: Performance Suggestions (Missing Const & Large Build Methods)
class UiPerformanceSuggestionsRule extends UiAstRuleContract {
  const UiPerformanceSuggestionsRule();

  @override
  String get id => 'ui.performance.missing-const';

  @override
  String get title => 'Missing const modifier or large build method';

  @override
  String get description =>
      'Provides informational performance suggestions for const-eligible widgets and oversized build methods.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.info;

  @override
  double get defaultConfidence => 0.65;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];

    ArgumentList? argumentList;
    var isConst = false;
    if (node is InstanceCreationExpression) {
      argumentList = node.argumentList;
      isConst = node.isConst;
    } else if (node is MethodInvocation) {
      argumentList = node.argumentList;
      isConst = false;
    }

    if (context.isInBuildMethod && argumentList != null && !isConst) {
      final typeName = AstAnalysisContext.extractWidgetName(node);
      if (typeName != null &&
          (WidgetTaxonomy.classify(typeName).isKnown ||
              (typeName.isNotEmpty &&
                  typeName[0] == typeName[0].toUpperCase()))) {
        if (!node.toSource().startsWith('const ') &&
            _areAllArgsConstLiterals(argumentList)) {
          issues.add(
            createIssue(
              node,
              context,
              customId: 'ui.performance.missing-const',
              customTitle: 'Missing const modifier on immutable widget',
              customSeverity: DiagnosticSeverity.info,
              customConfidence: 0.6,
              description:
                  'Widget $typeName constructor call can be declared const. '
                  'Using const widgets allows Flutter to short-circuit rebuilds and reuse existing element trees.',
              suggestion: 'Add the "const" keyword prefix to $typeName(...).',
            ),
          );
        }
      }
    }

    if (node is MethodDeclaration && node.name.lexeme == 'build') {
      final startLine = context.getLocation(node.offset).lineNumber;
      final endLine = context.getLocation(node.endToken.offset).lineNumber;
      final lineCount = endLine - startLine + 1;

      if (lineCount > 100) {
        issues.add(
          createIssue(
            node,
            context,
            customId: 'ui.performance.large-build-method',
            customTitle: 'Large build() method detected',
            customSeverity: DiagnosticSeverity.info,
            customConfidence: 0.75,
            description:
                'Build method is $lineCount lines long. '
                'Large monolithic build methods hurt code readability and trigger unnecessary rebuilds of large widget subtrees.',
            suggestion:
                'Refactor large build methods into smaller, reusable StatelessWidget classes.',
          ),
        );
      }
    }

    return issues;
  }

  bool _areAllArgsConstLiterals(ArgumentList args) {
    if (args.arguments.isEmpty) return true;
    for (final arg in args.arguments) {
      Expression expr = arg;
      if (arg is NamedExpression) {
        expr = arg.expression;
      }
      if (expr is StringLiteral ||
          expr is IntegerLiteral ||
          expr is DoubleLiteral ||
          expr is BooleanLiteral ||
          (expr is InstanceCreationExpression && expr.isConst)) {
        continue;
      }
      return false;
    }
    return true;
  }
}

/// Rule 11: Eager Large List Rule
class UiEagerLargeListRule extends UiAstRuleContract {
  const UiEagerLargeListRule();

  @override
  String get id => 'ui.eager-large-list';

  @override
  String get title => 'Large eager ListView or GridView children list';

  @override
  String get description =>
      'Detects ListView(children: [...]) or GridView(children: [...]) with > 20 literal children.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.low;

  @override
  double get defaultConfidence => 0.8;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);
    if (typeName == 'ListView' || typeName == 'GridView') {
      final args = AstAnalysisContext.getNamedArguments(node);
      final childrenArg = args['children'];
      if (childrenArg is ListLiteral && childrenArg.elements.length > 20) {
        issues.add(
          createIssue(
            node,
            context,
            description:
                'Eager $typeName contains ${childrenArg.elements.length} literal children. '
                'Instantiating large lists eagerly consumes memory and delays initial render.',
            suggestion:
                'Use $typeName.builder to lazily instantiate children on demand.',
          ),
        );
      }
    }
    return issues;
  }
}

/// Rule 12: Unlabeled Interactive Control
class UiUnlabeledInteractiveRule extends UiAstRuleContract {
  const UiUnlabeledInteractiveRule();

  @override
  String get id => 'ui.accessibility.unlabeled-interactive';

  @override
  String get title =>
      'Interactive control missing accessibility tooltip or label';

  @override
  String get description =>
      'Detects IconButton, FloatingActionButton, or InkWell missing tooltip or semantics.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.info;

  @override
  double get defaultConfidence => 0.7;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);
    if (typeName == 'IconButton' || typeName == 'FloatingActionButton') {
      final args = AstAnalysisContext.getNamedArguments(node);
      final hasTooltip = args.containsKey('tooltip');
      final hasSemantics = args.containsKey('semanticsLabel');

      if (!hasTooltip && !hasSemantics) {
        issues.add(
          createIssue(
            node,
            context,
            description:
                '$typeName is missing a tooltip or semanticsLabel for screen readers.',
            suggestion:
                'Add a tooltip or semanticsLabel parameter to clarify control action.',
          ),
        );
      }
    }
    return issues;
  }
}

/// Rule 13: Unlabeled Form Field
class UiUnlabeledFormFieldRule extends UiAstRuleContract {
  const UiUnlabeledFormFieldRule();

  @override
  String get id => 'ui.accessibility.unlabeled-form-field';

  @override
  String get title => 'Form input field missing label or hint text';

  @override
  String get description =>
      'Detects TextField or TextFormField missing InputDecoration labelText or hintText.';

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.info;

  @override
  double get defaultConfidence => 0.7;

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    final issues = <DiagnosticIssue>[];
    final typeName = AstAnalysisContext.extractWidgetName(node);
    if (typeName == 'TextField' || typeName == 'TextFormField') {
      final args = AstAnalysisContext.getNamedArguments(node);
      final decoration = args['decoration'];
      var hasLabel = false;

      if (decoration != null) {
        final decArgs = AstAnalysisContext.getNamedArguments(decoration);
        hasLabel =
            decArgs.containsKey('labelText') ||
            decArgs.containsKey('hintText') ||
            decArgs.containsKey('label');
      }

      if (!hasLabel) {
        issues.add(
          createIssue(
            node,
            context,
            description:
                '$typeName is missing a labelText or hintText in decoration.',
            suggestion:
                'Add labelText or hintText to InputDecoration for accessibility and UX clarity.',
          ),
        );
      }
    }
    return issues;
  }
}
