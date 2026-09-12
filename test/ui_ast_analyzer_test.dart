import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 3 UI AST Rule Engine Tests', () {
    test('Valid layout produces zero high-severity issues', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/valid_layout.dart',
      );
      final highIssues = result.issues.where(
        (i) =>
            i.severity == DiagnosticSeverity.high ||
            i.severity == DiagnosticSeverity.critical,
      );
      expect(highIssues, isEmpty);
      expect(result.parseErrors, isEmpty);
    });

    test('Detects nested scrollables and nested shrinkWrap', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/nested_scrollable.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui.nested-scrollable'));
      expect(issueIds, contains('ui.nested-shrink-wrap'));
    });

    test('Detects unconstrained scrollable inside Column', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/unconstrained_scrollable.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui.unconstrained-scrollable'));
      final issue = result.issues.firstWhere(
        (i) => i.id == 'ui.unconstrained-scrollable',
      );
      expect(issue.severity, DiagnosticSeverity.high);
    });

    test('Detects Expanded misuse outside Column/Row/Flex', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/expanded_misuse.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui.expanded-misuse'));
      final issue = result.issues.firstWhere(
        (i) => i.id == 'ui.expanded-misuse',
      );
      expect(issue.severity, DiagnosticSeverity.high);
    });

    test('Detects oversized hardcoded dimensions', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/oversized_dimension.dart',
      );
      final oversizedIssues = result.issues.where(
        (i) => i.id == 'ui.oversized-dimension',
      );

      expect(oversizedIssues.length, 2); // width and height > 1000
    });

    test('Detects suspicious setState inside build method', () async {
      final result = await UiAstAnalyzer.analyzeFile(
        'test/fixtures/ui/suspicious_setstate.dart',
      );
      final issueIds = result.issues.map((i) => i.id).toList();

      expect(issueIds, contains('ui.build.setstate'));
      final issue = result.issues.firstWhere(
        (i) => i.id == 'ui.build.setstate',
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
          (i) => i.id == 'ui.unconstrained-scrollable',
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
          (i) => i.id == 'ui.build.setstate',
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
          (i) => i.id == 'ui.build.setstate',
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
          (i) => i.id == 'ui.nested-scrollable',
        );
        expect(nestedIssues, isEmpty);
      },
    );

    test(
      'Horizontal ListView nested in vertical scrollable produces INFO severity',
      () {
        const code = '''
import 'package:flutter/material.dart';

Widget buildTree(BuildContext context) {
  return ListView(
    children: [
      SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: const [Text('Item 1')],
        ),
      ),
    ],
  );
}
''';
        final result = UiAstAnalyzer.analyzeSource(code);
        final horizontalIssues = result.issues.where(
          (i) => i.id == 'ui.nested-horizontal-scrollable',
        );
        expect(horizontalIssues, hasLength(1));
        expect(horizontalIssues.first.severity, DiagnosticSeverity.info);
        expect(
          horizontalIssues.first.title,
          'Nested cross-axis scrollable pattern detected',
        );
      },
    );
  });
}
