import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'widget_taxonomy.dart';

/// Rich contextual information during Dart AST traversal.
class AstAnalysisContext {
  AstAnalysisContext({
    required this.filePath,
    required this.lineInfo,
    this.currentClass,
    this.currentMethod,
    this.currentFunction,
    List<AstNode>? ancestorChain,
    List<AstNode>? widgetStack,
    this.callbackDepth = 0,
    this.isInBuildMethod = false,
    this.isConstantContext = false,
  }) : ancestorChain = ancestorChain ?? <AstNode>[],
       widgetStack = widgetStack ?? <AstNode>[];

  final String filePath;
  final LineInfo lineInfo;
  final ClassDeclaration? currentClass;
  final MethodDeclaration? currentMethod;
  final FunctionDeclaration? currentFunction;
  final List<AstNode> ancestorChain;
  final List<AstNode> widgetStack;
  final int callbackDepth;
  final bool isInBuildMethod;
  final bool isConstantContext;

  bool get isInCallback => callbackDepth > 0;

  /// Returns nearest ancestor node of type [T].
  T? findAncestor<T extends AstNode>() {
    for (final node in ancestorChain.reversed) {
      if (node is T) return node;
    }
    return null;
  }

  /// Returns nearest ancestor widget node with matching name.
  AstNode? findAncestorWidget(String widgetName) {
    for (final expr in widgetStack.reversed) {
      if (extractWidgetName(expr) == widgetName) {
        return expr;
      }
    }
    return null;
  }

  /// Checks if any ancestor widget matches a specific taxonomy category.
  bool hasAncestorTaxonomyCategory(WidgetTaxonomyCategory category) {
    for (final expr in widgetStack.reversed) {
      final name = extractWidgetName(expr);
      if (name != null) {
        final classification = WidgetTaxonomy.classify(name);
        if (classification.category == category) {
          return true;
        }
      }
    }
    return false;
  }

  /// Extracts the simple widget name from an AST node.
  static String? extractWidgetName(AstNode node) {
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

  /// Map of named arguments for a widget creation expression or method invocation.
  static Map<String, Expression> getNamedArguments(AstNode node) {
    final map = <String, Expression>{};
    ArgumentList? argumentList;
    if (node is InstanceCreationExpression) {
      argumentList = node.argumentList;
    } else if (node is MethodInvocation) {
      argumentList = node.argumentList;
    }
    if (argumentList != null) {
      for (final arg in argumentList.arguments) {
        if (arg is NamedExpression) {
          map[arg.name.label.name] = arg.expression;
        }
      }
    }
    return map;
  }

  /// Returns (line, column) for a character offset.
  CharacterLocation getLocation(int offset) {
    return lineInfo.getLocation(offset);
  }
}

/// Visitor that builds and updates [AstAnalysisContext] as it traverses the AST.
class AstContextVisitor extends GeneralizingAstVisitor<void> {
  AstContextVisitor({
    required this.filePath,
    required this.lineInfo,
    required this.onNodeVisited,
  });

  final String filePath;
  final LineInfo lineInfo;
  final void Function(AstNode node, AstAnalysisContext context) onNodeVisited;

  ClassDeclaration? _currentClass;
  MethodDeclaration? _currentMethod;
  FunctionDeclaration? _currentFunction;
  final List<AstNode> _ancestors = [];
  final List<AstNode> _widgetStack = [];
  int _callbackDepth = 0;
  bool _isInBuildMethod = false;
  bool _isConstantContext = false;

  AstAnalysisContext _createContext() {
    return AstAnalysisContext(
      filePath: filePath,
      lineInfo: lineInfo,
      currentClass: _currentClass,
      currentMethod: _currentMethod,
      currentFunction: _currentFunction,
      ancestorChain: List<AstNode>.from(_ancestors),
      widgetStack: List<AstNode>.from(_widgetStack),
      callbackDepth: _callbackDepth,
      isInBuildMethod: _isInBuildMethod,
      isConstantContext: _isConstantContext,
    );
  }

  @override
  void visitNode(AstNode node) {
    final isClass = node is ClassDeclaration;
    final isMethod = node is MethodDeclaration;
    final isFunction = node is FunctionDeclaration;

    final prevClass = _currentClass;
    final prevMethod = _currentMethod;
    final prevFunction = _currentFunction;
    final prevInBuild = _isInBuildMethod;
    final prevConst = _isConstantContext;

    if (node is ClassDeclaration) {
      _currentClass = node;
    }
    if (node is MethodDeclaration) {
      _currentMethod = node;
      if (node.name.lexeme == 'build') {
        _isInBuildMethod = true;
      }
    }
    if (node is FunctionDeclaration) {
      _currentFunction = node;
      if (node.name.lexeme == 'build') {
        _isInBuildMethod = true;
      }
    }

    final isCallback =
        node is FunctionExpression &&
        _ancestors.isNotEmpty &&
        _ancestors.any((a) => a is NamedExpression || a is ArgumentList);

    if (isCallback) _callbackDepth++;

    final widgetName = AstAnalysisContext.extractWidgetName(node);
    final isWidget =
        (node is InstanceCreationExpression || node is MethodInvocation) &&
        widgetName != null &&
        widgetName.isNotEmpty &&
        widgetName[0].toUpperCase() == widgetName[0];

    if (isWidget) {
      _widgetStack.add(node);
    }
    if (node is InstanceCreationExpression && node.isConst) {
      _isConstantContext = true;
    }

    _ancestors.add(node);
    onNodeVisited(node, _createContext());

    super.visitNode(node);

    _ancestors.removeLast();

    if (isWidget) {
      _widgetStack.removeLast();
    }
    if (isCallback) {
      _callbackDepth--;
    }

    if (isClass) _currentClass = prevClass;
    if (isMethod) {
      _currentMethod = prevMethod;
      _isInBuildMethod = prevInBuild;
    }
    if (isFunction) {
      _currentFunction = prevFunction;
      _isInBuildMethod = prevInBuild;
    }
    if (node is InstanceCreationExpression) _isConstantContext = prevConst;
  }
}
