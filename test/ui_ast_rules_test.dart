import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('1. Scroll Rules & Mitigations', () {
    test('Detects unmitigated same-axis nested scrollable', () {
      const code = '''
Widget build(BuildContext context) {
  return ListView(
    children: [
      ListView(
        children: [
          Text("Item"),
        ],
      ),
    ],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues, isNotEmpty);
      expect(res.issues.any((i) => i.id == 'ui.nested-scrollable'), isTrue);
    });

    test(
      'Recognizes NeverScrollableScrollPhysics mitigation on nested scrollable',
      () {
        const code = '''
Widget build(BuildContext context) {
  return ListView(
    children: [
      ListView(
        physics: NeverScrollableScrollPhysics(),
        children: [
          Text("Item"),
        ],
      ),
    ],
  );
}
''';
        final res = UiAstAnalyzer.analyzeSource(
          code,
          filePath: 'lib/screen.dart',
        );
        expect(
          res.issues.where((i) => i.id == 'ui.nested-scrollable'),
          isEmpty,
        );
      },
    );

    test('Recognizes cross-axis scroll direction (carousel pattern)', () {
      const code = '''
Widget build(BuildContext context) {
  return ListView(
    children: [
      ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Text("Carousel Item"),
        ],
      ),
    ],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.nested-horizontal-scrollable'),
        isTrue,
      );
      expect(
        res.issues.any((i) => i.severity == DiagnosticSeverity.info),
        isTrue,
      );
    });

    test('Recognizes CustomScrollView with Slivers as valid pattern', () {
      const code = '''
Widget build(BuildContext context) {
  return CustomScrollView(
    slivers: [
      SliverList(
        delegate: SliverChildListDelegate([
          Text("Header"),
        ]),
      ),
    ],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.where((i) => i.id == 'ui.nested-scrollable'), isEmpty);
    });
  });

  group('2. Flex & Constraint Misuse Rules', () {
    test('Detects Expanded used outside Row, Column, or Flex', () {
      const code = '''
Widget build(BuildContext context) {
  return Container(
    child: Expanded(
      child: Text("Invalid"),
    ),
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.any((i) => i.id == 'ui.expanded-misuse'), isTrue);
    });

    test('Allows Expanded inside Column or Row', () {
      const code = '''
Widget build(BuildContext context) {
  return Column(
    children: [
      Expanded(
        child: Text("Valid"),
      ),
    ],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.where((i) => i.id == 'ui.expanded-misuse'), isEmpty);
    });

    test('Detects Positioned used outside Stack', () {
      const code = '''
Widget build(BuildContext context) {
  return Container(
    child: Positioned(
      left: 10,
      child: Text("Invalid"),
    ),
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.any((i) => i.id == 'ui.positioned-misuse'), isTrue);
    });

    test('Allows Positioned inside Stack', () {
      const code = '''
Widget build(BuildContext context) {
  return Stack(
    children: [
      Positioned(
        left: 10,
        child: Text("Valid"),
      ),
    ],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.where((i) => i.id == 'ui.positioned-misuse'), isEmpty);
    });

    test('Detects double.infinity height inside Column', () {
      const code = '''
Widget build(BuildContext context) {
  return Column(
    children: [
      SizedBox(
        height: double.infinity,
        child: Text("Invalid"),
      ),
    ],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.any((i) => i.id == 'ui.unbounded-dimension'), isTrue);
    });
  });

  group('3. Build Method Heavy Operations Rules', () {
    test('Detects setState() called directly in build()', () {
      const code = '''
Widget build(BuildContext context) {
  setState(() {});
  return Text("Hello");
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.any((i) => i.id == 'ui.build.setstate'), isTrue);
    });

    test('Allows setState() inside button onPressed callback', () {
      const code = '''
Widget build(BuildContext context) {
  return ElevatedButton(
    onPressed: () {
      setState(() {});
    },
    child: Text("Click"),
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.where((i) => i.id == 'ui.build.setstate'), isEmpty);
    });

    test(
      'Detects jsonDecode and controller instantiation directly inside build()',
      () {
        const code = '''
Widget build(BuildContext context) {
  final controller = TextEditingController();
  final data = jsonDecode('{"key": "value"}');
  return TextField(controller: controller);
}
''';
        final res = UiAstAnalyzer.analyzeSource(
          code,
          filePath: 'lib/screen.dart',
        );
        expect(
          res.issues.any((i) => i.id == 'ui.build.expensive-operation'),
          isTrue,
        );
      },
    );
  });

  group('4. Eager Large List Rule', () {
    test('Detects eager ListView with > 20 literal children', () {
      final items = List.generate(25, (i) => 'Text("Item $i")').join(', ');
      final code =
          '''
Widget build(BuildContext context) {
  return ListView(
    children: [$items],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.any((i) => i.id == 'ui.eager-large-list'), isTrue);
    });

    test('Allows small eager ListView with <= 20 literal children', () {
      const code = '''
Widget build(BuildContext context) {
  return ListView(
    children: [
      Text("1"), Text("2"), Text("3"),
    ],
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(res.issues.where((i) => i.id == 'ui.eager-large-list'), isEmpty);
    });
  });

  group('5. Accessibility Rules', () {
    test('Detects IconButton missing tooltip and semanticsLabel', () {
      const code = '''
Widget build(BuildContext context) {
  return IconButton(
    icon: Icon(Icons.add),
    onPressed: () {},
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.accessibility.unlabeled-interactive'),
        isTrue,
      );
    });

    test('Allows IconButton with tooltip parameter', () {
      const code = '''
Widget build(BuildContext context) {
  return IconButton(
    icon: Icon(Icons.add),
    tooltip: 'Add item',
    onPressed: () {},
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.where(
          (i) => i.id == 'ui.accessibility.unlabeled-interactive',
        ),
        isEmpty,
      );
    });

    test('Detects TextField missing decoration label', () {
      const code = '''
Widget build(BuildContext context) {
  return TextField();
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.accessibility.unlabeled-form-field'),
        isTrue,
      );
    });

    test('Allows TextField with labelText in InputDecoration', () {
      const code = '''
Widget build(BuildContext context) {
  return TextField(
    decoration: InputDecoration(labelText: 'Username'),
  );
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.where(
          (i) => i.id == 'ui.accessibility.unlabeled-form-field',
        ),
        isEmpty,
      );
    });
  });

  group('6. Controller Disposal Rules', () {
    test('Detects undisposed TextEditingController in State class', () {
      const code = '''
import 'package:flutter/material.dart';

class MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.lifecycle.undisposed-controller'),
        isTrue,
      );
    });

    test('Allows controller disposed in dispose() method', () {
      const code = '''
import 'package:flutter/material.dart';

class MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.where((i) => i.id == 'ui.lifecycle.undisposed-controller'),
        isEmpty,
      );
    });

    test('Allows controller injected from widget properties', () {
      const code = '''
import 'package:flutter/material.dart';

class MyWidgetState extends State<MyWidget> {
  late final controller = widget.externalController;

  @override
  Widget build(BuildContext context) {
    return TextField(controller: controller);
  }
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.where((i) => i.id == 'ui.lifecycle.undisposed-controller'),
        isEmpty,
      );
    });
  });

  group('7. Subscription and Timer Cleanup Rules', () {
    test('Detects uncancelled StreamSubscription or Timer in State', () {
      const code = '''
import 'dart:async';
import 'package:flutter/material.dart';

class MyWidgetState extends State<MyWidget> {
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = stream.listen((data) {});
  }

  @override
  Widget build(BuildContext context) => Container();
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.lifecycle.undisposed-subscription'),
        isTrue,
      );
    });

    test('Allows StreamSubscription cancelled in dispose()', () {
      const code = '''
import 'dart:async';
import 'package:flutter/material.dart';

class MyWidgetState extends State<MyWidget> {
  late StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.where((i) => i.id == 'ui.lifecycle.undisposed-subscription'),
        isEmpty,
      );
    });
  });

  group('8. Async Lifecycle Safety Rules', () {
    test('Detects setState after await without mounted check', () {
      const code = '''
import 'package:flutter/material.dart';

class MyWidgetState extends State<MyWidget> {
  Future<void> _load() async {
    await fetchData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Container();
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.async.setstate-unmounted'),
        isTrue,
      );
    });

    test('Allows setState after await when mounted check is present', () {
      const code = '''
import 'package:flutter/material.dart';

class MyWidgetState extends State<MyWidget> {
  Future<void> _load() async {
    await fetchData();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Container();
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.where((i) => i.id == 'ui.async.setstate-unmounted'),
        isEmpty,
      );
    });

    test('Detects BuildContext usage after await without context.mounted', () {
      const code = '''
import 'package:flutter/material.dart';

void navigate(BuildContext context) async {
  await fetchData();
  Navigator.of(context).pop();
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.async.use-build-context'),
        isTrue,
      );
    });
  });

  group('9. Extended Build-Method Anti-Patterns', () {
    test('Detects DB query and Future creation inside build()', () {
      const code = '''
import 'package:flutter/material.dart';

Widget build(BuildContext context) {
  final f = Future.delayed(Duration(seconds: 1));
  database.rawQuery("SELECT * FROM items");
  return Text("Hello");
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.where((i) => i.id == 'ui.build.expensive-operation').length,
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('10. Performance Suggestions', () {
    test('Suggests const prefix for immutable widget in build()', () {
      const code = '''
import 'package:flutter/material.dart';

Widget build(BuildContext context) {
  return Text('Static Text');
}
''';
      final res = UiAstAnalyzer.analyzeSource(
        code,
        filePath: 'lib/screen.dart',
      );
      expect(
        res.issues.any((i) => i.id == 'ui.performance.missing-const'),
        isTrue,
      );
    });
  });
}
