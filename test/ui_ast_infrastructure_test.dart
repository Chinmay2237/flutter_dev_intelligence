import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingMockRule extends UiAstRuleContract {
  const FailingMockRule();

  @override
  String get id => 'failing_mock_rule';

  @override
  String get title => 'Failing mock rule';

  @override
  String get description =>
      'Always throws an exception to test error isolation.';

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    if (node is InstanceCreationExpression || node is MethodInvocation) {
      throw Exception('Intentional mock rule failure');
    }
    return const [];
  }
}

class PassingMockRule extends UiAstRuleContract {
  const PassingMockRule();

  @override
  String get id => 'passing_mock_rule';

  @override
  String get title => 'Passing mock rule';

  @override
  String get description => 'Always returns an issue for test nodes.';

  @override
  List<DiagnosticIssue> checkNode(AstNode node, AstAnalysisContext context) {
    if (node is InstanceCreationExpression || node is MethodInvocation) {
      final name = AstAnalysisContext.extractWidgetName(node);
      if (name == 'SizedBox') {
        return [
          createIssue(
            node,
            context,
            description: 'Passing rule issue',
            suggestion: 'Fix issue',
          ),
        ];
      }
    }
    return const [];
  }
}

void main() {
  group('1. Source Discovery (AstSourceDiscoverer)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ast_discoverer_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Discovers Dart files recursively and sorts paths', () async {
      final f2 = File('${tempDir.path}${Platform.pathSeparator}b_file.dart');
      final f1 = File('${tempDir.path}${Platform.pathSeparator}a_file.dart');
      await f1.writeAsString('void main() {}');
      await f2.writeAsString('void main() {}');

      const discoverer = AstSourceDiscoverer();
      final result = await discoverer.discover(tempDir.path);

      expect(result.discoveredPaths, hasLength(2));
      expect(result.discoveredPaths.first, contains('a_file.dart'));
      expect(result.discoveredPaths.last, contains('b_file.dart'));
    });

    test('Excludes generated files when excludeGenerated is true', () async {
      final genFile = File(
        '${tempDir.path}${Platform.pathSeparator}user.g.dart',
      );
      final regularFile = File(
        '${tempDir.path}${Platform.pathSeparator}user.dart',
      );
      await genFile.writeAsString('// generated');
      await regularFile.writeAsString('class User {}');

      const discoverer = AstSourceDiscoverer();
      final result = await discoverer.discover(
        tempDir.path,
        config: const ProjectConfig(excludeGenerated: true),
      );

      expect(result.discoveredPaths, hasLength(1));
      expect(result.discoveredPaths.first, contains('user.dart'));
    });

    test('Skips large files exceeding size threshold', () async {
      final largeFile = File(
        '${tempDir.path}${Platform.pathSeparator}large.dart',
      );
      final sink = largeFile.openWrite();
      for (var i = 0; i < 200; i++) {
        sink.writeln('// ${'a' * 1000}');
      }
      await sink.close();

      final discoverer = AstSourceDiscoverer(
        maxSizeBytes: 100 * 1024,
      ); // 100KB threshold
      final result = await discoverer.discover(tempDir.path);

      expect(result.discoveredPaths, isEmpty);
      expect(result.skippedFiles, contains(contains('exceeds')));
    });
  });

  group('2. Resilient Parsing (AstParser)', () {
    test('Parses valid Dart source smoothly', () {
      const code =
          'class SampleWidget extends StatelessWidget { const SampleWidget({super.key}); }';
      final result = AstParser.parse(code);

      expect(result.isValid, isTrue);
      expect(result.unit, isNotNull);
      expect(result.parseErrors, isEmpty);
      expect(result.hasFatalError, isFalse);
    });

    test('Captures syntax errors gracefully without throwing exceptions', () {
      const code = 'class BrokenWidget { void build( { invalid syntax here ';
      final result = AstParser.parse(code);

      expect(result.hasFatalError, isFalse);
      expect(result.parseErrors, isNotEmpty);
      expect(result.parseErrors.first.message, isNotEmpty);
    });

    test('Handles empty and whitespace-only source files', () {
      final result = AstParser.parse('   \n\n');
      expect(result.hasFatalError, isFalse);
      expect(result.parseErrors, isEmpty);
    });
  });

  group('3. Widget Taxonomy Classification (WidgetTaxonomy)', () {
    test('Classifies standard Flutter scrollables', () {
      expect(
        WidgetTaxonomy.classify('ListView').category,
        WidgetTaxonomyCategory.scrollable,
      );
      expect(
        WidgetTaxonomy.classify('GridView').category,
        WidgetTaxonomyCategory.scrollable,
      );
      expect(
        WidgetTaxonomy.classify('CustomScrollView').category,
        WidgetTaxonomyCategory.scrollable,
      );
      expect(WidgetTaxonomy.isScrollable('SingleChildScrollView'), isTrue);
    });

    test('Classifies standard flex containers and flex items', () {
      expect(
        WidgetTaxonomy.classify('Row').category,
        WidgetTaxonomyCategory.flexContainer,
      );
      expect(
        WidgetTaxonomy.classify('Column').category,
        WidgetTaxonomyCategory.flexContainer,
      );
      expect(
        WidgetTaxonomy.classify('Expanded').category,
        WidgetTaxonomyCategory.flexItem,
      );
      expect(
        WidgetTaxonomy.classify('Flexible').category,
        WidgetTaxonomyCategory.flexItem,
      );
    });

    test('Classifies standard sliver widgets', () {
      expect(
        WidgetTaxonomy.classify('SliverList').category,
        WidgetTaxonomyCategory.sliver,
      );
      expect(
        WidgetTaxonomy.classify('SliverAppBar').category,
        WidgetTaxonomyCategory.sliver,
      );
      expect(WidgetTaxonomy.isSliver('SliverToBoxAdapter'), isTrue);
    });

    test('Classifies custom unknown widgets with unknown resolution state', () {
      final classification = WidgetTaxonomy.classify('MyCustomHeader');
      expect(classification.category, WidgetTaxonomyCategory.custom);
      expect(classification.resolutionState, WidgetResolutionState.unknown);
      expect(classification.isUnknown, isTrue);
    });
  });

  group('4. Context Tracking & Traversal (AstAnalysisContext & Visitor)', () {
    test('Tracks build method, ancestor stack, and callback depth', () {
      const source = '''
class MyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            print("clicked");
          },
          child: Text("Click"),
        ),
      ],
    );
  }
}
''';

      final parseResult = AstParser.parse(source, filePath: 'lib/my_card.dart');
      expect(parseResult.unit, isNotNull);

      var observedInBuild = false;
      var observedCallbackDepth = 0;
      var observedMaxWidgetStack = 0;

      final visitor = AstContextVisitor(
        filePath: 'lib/my_card.dart',
        lineInfo: parseResult.lineInfo!,
        onNodeVisited: (node, context) {
          if (context.isInBuildMethod) observedInBuild = true;
          if (context.callbackDepth > observedCallbackDepth) {
            observedCallbackDepth = context.callbackDepth;
          }
          if (context.widgetStack.length > observedMaxWidgetStack) {
            observedMaxWidgetStack = context.widgetStack.length;
          }
        },
      );

      parseResult.unit!.accept(visitor);

      expect(observedInBuild, isTrue);
      expect(observedCallbackDepth, greaterThanOrEqualTo(1));
      expect(observedMaxWidgetStack, greaterThanOrEqualTo(2));
    });
  });

  group('5. Rule Execution & Error Isolation (RuleExecutor)', () {
    test('Isolates rule exceptions without crashing entire analysis', () {
      const source = '''
Widget build(BuildContext context) {
  return SizedBox(width: 100);
}
''';
      final parseResult = AstParser.parse(source, filePath: 'lib/main.dart');

      const registry = UiAstRuleRegistry(
        rules: [FailingMockRule(), PassingMockRule()],
      );

      final execResult = RuleExecutor.execute(
        unit: parseResult.unit!,
        filePath: 'lib/main.dart',
        lineInfo: parseResult.lineInfo!,
        registry: registry,
      );

      expect(execResult.ruleErrors, isNotEmpty);
      expect(
        execResult.ruleErrors.first,
        contains('Intentional mock rule failure'),
      );
      expect(execResult.issues, isNotEmpty);
      expect(execResult.issues.any((i) => i.id == 'passing_mock_rule'), isTrue);
      expect(
        execResult.issues.any((i) => i.id == 'rule_execution_failure'),
        isTrue,
      );
    });

    test('Sorts execution findings deterministically', () {
      const source = '''
Widget build(BuildContext context) {
  return Column(
    children: [
      SizedBox(height: 10),
      SizedBox(height: 20),
    ],
  );
}
''';
      final parseResult = AstParser.parse(source, filePath: 'lib/main.dart');
      const registry = UiAstRuleRegistry(rules: [PassingMockRule()]);

      final result = RuleExecutor.execute(
        unit: parseResult.unit!,
        filePath: 'lib/main.dart',
        lineInfo: parseResult.lineInfo!,
        registry: registry,
      );

      for (var i = 0; i < result.issues.length - 1; i++) {
        final current = result.issues[i];
        final next = result.issues[i + 1];
        expect((current.line ?? 0) <= (next.line ?? 0), isTrue);
      }
    });
  });
}
