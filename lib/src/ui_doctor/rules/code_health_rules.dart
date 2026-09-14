import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../core/models.dart';
import 'ui_rule_base.dart';

/// Visitor for detecting debugPrint or print statements in Dart AST.
class _DebugPrintVisitor extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> debugCalls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'debugPrint' || name == 'print') {
      debugCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Visitor for analyzing class declarations and build method sizes.
class _WidgetClassVisitor extends RecursiveAstVisitor<void> {
  final List<ClassDeclaration> largeClasses = [];
  final List<MethodDeclaration> largeBuildMethods = [];

  final int maxWidgetClassLines;
  final int maxBuildMethodLines;
  final LineInfo lineInfo;

  _WidgetClassVisitor({
    required this.lineInfo,
    this.maxWidgetClassLines = 300,
    this.maxBuildMethodLines = 100,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superclass = node.extendsClause?.superclass.toString();
    final isWidgetClass =
        superclass == 'StatelessWidget' ||
        superclass == 'StatefulWidget' ||
        (superclass != null && superclass.startsWith('State'));

    if (isWidgetClass) {
      final startLine = lineInfo.getLocation(node.offset).lineNumber;
      final endLine = lineInfo.getLocation(node.end).lineNumber;
      final classLineCount = endLine - startLine + 1;

      if (classLineCount > maxWidgetClassLines) {
        largeClasses.add(node);
      }
    }

    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      final parentClass = node.parent;
      if (parentClass is ClassDeclaration) {
        final startLine = lineInfo.getLocation(node.offset).lineNumber;
        final endLine = lineInfo.getLocation(node.end).lineNumber;
        final buildLineCount = endLine - startLine + 1;

        if (buildLineCount > maxBuildMethodLines) {
          largeBuildMethods.add(node);
        }
      }
    }
    super.visitMethodDeclaration(node);
  }
}

/// Rule detecting debugPrint or print statements left in production source code.
class DebugPrintInProdRule extends UiDoctorRule {
  /// Creates a new [DebugPrintInProdRule] instance.
  const DebugPrintInProdRule();

  @override
  String get id => 'UI_DEBUG_PRINT_IN_PROD';

  @override
  String get title => 'Debug Print Logging in Production Source';

  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.warning;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'maintainability';

  @override
  List<DiagnosticFinding> analyzeDartFile({
    required String filePath,
    required String relativePath,
    required String content,
    required CompilationUnit ast,
  }) {
    final findings = <DiagnosticFinding>[];
    final visitor = _DebugPrintVisitor();
    ast.visitChildren(visitor);

    final lineInfo = ast.lineInfo;

    for (final call in visitor.debugCalls) {
      if (_isGuardedByDebugMode(call)) continue;

      final line = lineInfo.getLocation(call.offset).lineNumber;
      final methodName = call.methodName.name;

      findings.add(
        DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary: 'Use of "$methodName()" found at $relativePath:$line.',
          likelyCause:
              'Raw debug logging statements degrade console performance and leak debug information in production builds.',
          source: 'ui_doctor',
          filePath: relativePath,
          line: line,
          primaryStatus: PrimaryStatus.independent,
          evidence: [
            EvidenceReference(
              label: 'Code invocation',
              value: call.toSource(),
              lineNumber: line,
              type: 'source',
            ),
          ],
          recommendations: [
            FixSuggestion(
              action:
                  'Remove "$methodName()" or wrap with debug check (e.g. if (kDebugMode)) or structured logging package.',
            ),
          ],
        ),
      );
    }

    return findings;
  }

  bool _isGuardedByDebugMode(AstNode node) {
    AstNode? current = node.parent;
    while (current != null &&
        current is! MethodDeclaration &&
        current is! FunctionDeclaration) {
      if (current is IfStatement) {
        final cond = current.expression.toSource();
        if (cond.contains('kDebugMode')) return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Rule detecting excessively large build() methods.
class LargeBuildMethodRule extends UiDoctorRule {
  /// Creates a new [LargeBuildMethodRule] instance with optional [maxLines] threshold.
  const LargeBuildMethodRule({this.maxLines = 100});

  /// Maximum allowed line count for a build method before flagging.
  final int maxLines;

  @override
  String get id => 'UI_LARGE_BUILD_METHOD';

  @override
  String get title => 'Excessively Large build() Method';

  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.warning;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'maintainability';

  @override
  List<DiagnosticFinding> analyzeDartFile({
    required String filePath,
    required String relativePath,
    required String content,
    required CompilationUnit ast,
  }) {
    final findings = <DiagnosticFinding>[];
    final visitor = _WidgetClassVisitor(
      lineInfo: ast.lineInfo,
      maxBuildMethodLines: maxLines,
    );
    ast.visitChildren(visitor);

    for (final method in visitor.largeBuildMethods) {
      final startLine = ast.lineInfo.getLocation(method.offset).lineNumber;
      final endLine = ast.lineInfo.getLocation(method.end).lineNumber;
      final totalLines = endLine - startLine + 1;

      final className = (method.parent as ClassDeclaration).name.lexeme;

      findings.add(
        DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary:
              'The build() method in widget "$className" spans $totalLines lines (exceeds $maxLines lines threshold).',
          likelyCause:
              'Large build methods degrade code maintainability, readability, and refactorability.',
          source: 'ui_doctor',
          filePath: relativePath,
          line: startLine,
          primaryStatus: PrimaryStatus.independent,
          evidence: [
            EvidenceReference(
              label: 'Method scope',
              value:
                  '$className.build() spans lines $startLine-$endLine ($totalLines lines)',
              lineNumber: startLine,
              type: 'source',
            ),
          ],
          recommendations: [
            FixSuggestion(
              action:
                  'Consider extracting independent sub-widgets or helper methods for maintainability.',
              details:
                  'This is a maintainability recommendation; size alone does not prove runtime performance degradation.',
            ),
          ],
        ),
      );
    }

    return findings;
  }
}

/// Rule detecting oversized Widget classes.
class LargeWidgetClassRule extends UiDoctorRule {
  /// Creates a new [LargeWidgetClassRule] instance with optional [maxLines] threshold.
  const LargeWidgetClassRule({this.maxLines = 300});

  /// Maximum allowed line count for a Widget class before flagging.
  final int maxLines;

  @override
  String get id => 'UI_LARGE_WIDGET_CLASS';

  @override
  String get title => 'Oversized Widget Class';

  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.warning;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'maintainability';

  @override
  List<DiagnosticFinding> analyzeDartFile({
    required String filePath,
    required String relativePath,
    required String content,
    required CompilationUnit ast,
  }) {
    final findings = <DiagnosticFinding>[];
    final visitor = _WidgetClassVisitor(
      lineInfo: ast.lineInfo,
      maxWidgetClassLines: maxLines,
    );
    ast.visitChildren(visitor);

    for (final clazz in visitor.largeClasses) {
      final startLine = ast.lineInfo.getLocation(clazz.offset).lineNumber;
      final endLine = ast.lineInfo.getLocation(clazz.end).lineNumber;
      final totalLines = endLine - startLine + 1;
      final className = clazz.name.lexeme;

      findings.add(
        DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary:
              'Widget class "$className" spans $totalLines lines (exceeds $maxLines lines threshold).',
          likelyCause:
              'Oversized widget classes combine multiple responsibilities, making maintenance and testing difficult.',
          source: 'ui_doctor',
          filePath: relativePath,
          line: startLine,
          primaryStatus: PrimaryStatus.independent,
          evidence: [
            EvidenceReference(
              label: 'Class bounds',
              value:
                  'Class $className spans lines $startLine-$endLine ($totalLines lines)',
              lineNumber: startLine,
              type: 'source',
            ),
          ],
          recommendations: [
            FixSuggestion(
              action:
                  'Refactor class responsibilities into separate controller logic and focused UI widgets.',
            ),
          ],
        ),
      );
    }

    return findings;
  }
}
