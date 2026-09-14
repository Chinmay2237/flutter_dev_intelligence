import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../core/models.dart';
import 'ui_rule_base.dart';

class _ShrinkWrapMatch {
  final AstNode node;
  final String widgetName;
  _ShrinkWrapMatch({required this.node, required this.widgetName});
}

class _ShrinkWrapVisitor extends RecursiveAstVisitor<void> {
  final List<_ShrinkWrapMatch> matches = [];

  static const _scrollableClasses = {
    'SingleChildScrollView',
    'ListView',
    'GridView',
    'CustomScrollView',
    'NestedScrollView',
    'PageView',
  };

  void _checkInvocation(
    AstNode node,
    String typeName,
    ArgumentList argumentList,
  ) {
    if (typeName == 'ListView' ||
        typeName == 'GridView' ||
        typeName == 'PageView') {
      final hasShrinkWrapTrue = argumentList.arguments.any((arg) {
        final src = arg.toSource().replaceAll(' ', '');
        return src.startsWith('shrinkWrap:true');
      });

      if (hasShrinkWrapTrue) {
        AstNode? current = node.parent;
        var insideScrollable = false;

        while (current != null) {
          final parentType = _extractTypeName(current);
          if (parentType != null && _scrollableClasses.contains(parentType)) {
            insideScrollable = true;
            break;
          }
          current = current.parent;
        }

        if (insideScrollable) {
          matches.add(_ShrinkWrapMatch(node: node, widgetName: typeName));
        }
      }
    }
  }

  String? _extractTypeName(AstNode node) {
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.toString();
    }
    if (node is MethodInvocation) {
      final target = node.target?.toString();
      if (target != null && target.isNotEmpty) return target;
      return node.methodName.name;
    }
    return null;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toString();
    _checkInvocation(node, typeName, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final typeName = _extractTypeName(node);
    if (typeName != null) {
      _checkInvocation(node, typeName, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }
}

/// Rule detecting shrinkWrap: true usage inside scrollable parent containers.
class ShrinkWrapInScrollableRule extends UiDoctorRule {
  /// Creates a new [ShrinkWrapInScrollableRule] instance.
  const ShrinkWrapInScrollableRule();

  @override
  String get id => 'UI_SHRINKWRAP_IN_SCROLLABLE';

  @override
  String get title => 'shrinkWrap: true Used Inside Scrollable Container';

  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.warning;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'performance';

  @override
  List<DiagnosticFinding> analyzeDartFile({
    required String filePath,
    required String relativePath,
    required String content,
    required CompilationUnit ast,
  }) {
    final findings = <DiagnosticFinding>[];
    final visitor = _ShrinkWrapVisitor();
    ast.visitChildren(visitor);

    for (final match in visitor.matches) {
      final line = ast.lineInfo.getLocation(match.node.offset).lineNumber;
      final typeName = match.widgetName;

      findings.add(
        DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary:
              'Potential nested-scroll performance concern: "$typeName(shrinkWrap: true)" inside scrollable context at $relativePath:$line.',
          likelyCause:
              'Static heuristic: Using shrinkWrap: true disables viewport virtualization for nested lists.',
          source: 'ui_doctor',
          filePath: relativePath,
          line: line,
          primaryStatus: PrimaryStatus.independent,
          evidence: [
            EvidenceReference(
              label: 'Widget invocation',
              value: match.node.toSource().length > 80
                  ? '${match.node.toSource().substring(0, 80)}...'
                  : match.node.toSource(),
              lineNumber: line,
              type: 'source',
            ),
          ],
          recommendations: [
            FixSuggestion(
              action:
                  'Review whether shrink wrapping is necessary. Consider replacing with Slivers (e.g. SliverList) or unnesting scrollables.',
              details:
                  'ShrinkWrap can be valid for small bounded lists, but disables virtualization in dynamic parent viewports.',
            ),
          ],
        ),
      );
    }

    return findings;
  }
}
