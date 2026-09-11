import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 3 UI AST Rule Engine Tests', () {
    test('Valid layout produces zero issues', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/valid_layout.dart',
      );
      expect(result.issues, isEmpty);
      expect(result.parseErrors, isEmpty);
    });

    test('Detects nested scrollables and nested shrinkWrap', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/nested_scrollable.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui_nested_scrollable'));
      expect(issueIds, contains('ui_nested_shrink_wrap'));
    });

    test('Detects unconstrained scrollable inside Column', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/unconstrained_scrollable.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui_unconstrained_scrollable'));
      final issue = result.issues.firstWhere(
        (i) => i.id == 'ui_unconstrained_scrollable',
      );
      expect(issue.severity, DiagnosticSeverity.high);
    });

    test('Detects Expanded misuse outside Column/Row/Flex', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/expanded_misuse.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui_expanded_misuse'));
      final issue = result.issues.firstWhere(
        (i) => i.id == 'ui_expanded_misuse',
      );
      expect(issue.severity, DiagnosticSeverity.high);
    });

    test('Detects oversized hardcoded dimensions', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/oversized_dimension.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui_oversized_dimension'));
      expect(result.issues.length, 2); // width and height > 1000
    });

    test('Detects suspicious setState inside build method', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/suspicious_setstate.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui_suspicious_setstate'));
      final issue = result.issues.firstWhere(
        (i) => i.id == 'ui_suspicious_setstate',
      );
      expect(issue.severity, DiagnosticSeverity.high);
      expect(issue.confidence, greaterThanOrEqualTo(0.9));
    });

    test(
      'Prevents false positives on constrained ListView inside SizedBox',
      () async {
        final result = await UiAstAnalyzer.analyzeFile(
          'test/fixtures/ui/false_positives.dart',
        );
        final unconstrainedIssues = result.issues.where(
          (i) => i.id == 'ui_unconstrained_scrollable',
        );

        expect(unconstrainedIssues, isEmpty);
      },
    );

    test(
      'setState inside callback function expression does not produce false positive',
      () {
        const code = '''
import 'package:flutter/material.dart';

class TestWidget extends StatefulWidget {
  const TestWidget({super.key});
  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _index = 1;
        });
      },
      child: Text('Tap \$_index'),
    );
  }
}
''';
        final result = UiAstAnalyzer.analyzeSource(code);
        final setStateIssues = result.issues.where(
          (i) => i.id == 'ui_suspicious_setstate',
        );
        expect(setStateIssues, isEmpty);
      },
    );

    test(
      'setState invoked directly in build method produces high severity issue',
      () {
        const code = '''
import 'package:flutter/material.dart';

class TestWidget extends StatefulWidget {
  const TestWidget({super.key});
  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    setState(() {
      _index = 1;
    });
    return Text('Index: \$_index');
  }
}
''';
        final result = UiAstAnalyzer.analyzeSource(code);
        final setStateIssues = result.issues.where(
          (i) => i.id == 'ui_suspicious_setstate',
        );
        expect(setStateIssues, hasLength(1));
        expect(setStateIssues.first.severity, DiagnosticSeverity.high);
      },
    );

    test(
      'Nested ListView with NeverScrollableScrollPhysics does not trigger scroll conflict',
      () {
        const code = '''
import 'package:flutter/material.dart';

Widget buildTree(BuildContext context) {
  return ListView(
    children: [
      ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: const [Text('Item 1')],
      ),
    ],
  );
}
''';
        final result = UiAstAnalyzer.analyzeSource(code);
        final nestedIssues = result.issues.where(
          (i) => i.id == 'ui_nested_scrollable',
        );
        expect(nestedIssues, isEmpty);
      },
    );
  });
}
