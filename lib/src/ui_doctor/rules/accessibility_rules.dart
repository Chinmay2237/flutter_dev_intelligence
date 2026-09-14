import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../core/models.dart';
import 'ui_rule_base.dart';

class _ImageMatch {
  final AstNode node;
  final String imageTypeName;
  _ImageMatch({required this.node, required this.imageTypeName});
}

class _MissingImageSemanticsVisitor extends RecursiveAstVisitor<void> {
  final List<_ImageMatch> matches = [];

  static const _imageConstructors = {
    'Image',
    'Image.asset',
    'Image.network',
    'Image.file',
    'Image.memory',
  };

  void _checkInvocation(
    AstNode node,
    String typeName,
    ArgumentList argumentList,
  ) {
    if (_imageConstructors.contains(typeName) ||
        typeName.startsWith('Image.')) {
      final hasSemanticLabel = argumentList.arguments.any((arg) {
        final src = arg.toSource().replaceAll(' ', '');
        return src.startsWith('semanticLabel:') ||
            src.startsWith('excludeFromSemantics:');
      });

      if (!hasSemanticLabel) {
        AstNode? current = node.parent;
        var wrappedInSemantics = false;

        while (current != null &&
            current is! MethodDeclaration &&
            current is! FunctionDeclaration) {
          final ancestorType = _extractTypeName(current);
          if (ancestorType == 'Semantics' ||
              ancestorType == 'ExcludeSemantics') {
            wrappedInSemantics = true;
            break;
          }
          current = current.parent;
        }

        if (!wrappedInSemantics) {
          matches.add(_ImageMatch(node: node, imageTypeName: typeName));
        }
      }
    }
  }

  String? _extractTypeName(AstNode node) {
    if (node is InstanceCreationExpression) {
      return node.constructorName.toString();
    }
    if (node is MethodInvocation) {
      final target = node.target?.toString();
      if (target != null && target.isNotEmpty) {
        return '$target.${node.methodName.name}';
      }
      return node.methodName.name;
    }
    return null;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.toString();
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

/// Rule detecting Image widgets missing semanticLabel descriptions.
class AccessibilityMissingImageSemanticsRule extends UiDoctorRule {
  /// Creates a new [AccessibilityMissingImageSemanticsRule] instance.
  const AccessibilityMissingImageSemanticsRule();

  @override
  String get id => 'UI_ACCESSIBILITY_MISSING_IMAGE_SEMANTICS';

  @override
  String get title => 'Image Widget Lacks Accessibility Semantics';

  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.warning;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'accessibility';

  @override
  List<DiagnosticFinding> analyzeDartFile({
    required String filePath,
    required String relativePath,
    required String content,
    required CompilationUnit ast,
  }) {
    final findings = <DiagnosticFinding>[];
    final visitor = _MissingImageSemanticsVisitor();
    ast.visitChildren(visitor);

    for (final match in visitor.matches) {
      final line = ast.lineInfo.getLocation(match.node.offset).lineNumber;
      final typeName = match.imageTypeName;

      findings.add(
        DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary:
              '"$typeName" at $relativePath:$line lacks a semanticLabel or Semantics parent widget.',
          likelyCause:
              'Screen readers cannot describe visual image assets without explicit semantic labels or Semantics context.',
          source: 'ui_doctor',
          filePath: relativePath,
          line: line,
          primaryStatus: PrimaryStatus.independent,
          evidence: [
            EvidenceReference(
              label: 'Image invocation',
              value: match.node.toSource().length > 70
                  ? '${match.node.toSource().substring(0, 70)}...'
                  : match.node.toSource(),
              lineNumber: line,
              type: 'source',
            ),
          ],
          recommendations: [
            FixSuggestion(
              action:
                  'Add semanticLabel to $typeName, set excludeFromSemantics: true for decorative images, or wrap with Semantics / ExcludeSemantics.',
            ),
          ],
        ),
      );
    }

    return findings;
  }
}
