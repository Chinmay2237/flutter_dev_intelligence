import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('UI Doctor Static Rule Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ui_doctor_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('UI_ASSET_MISSING_FILE flags missing asset files declared in pubspec', () async {
      final pubspecFile = File('${tempDir.path}${Platform.pathSeparator}pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_app
flutter:
  assets:
    - assets/images/missing_logo.png
''');

      const rule = AssetMissingFileRule();
      final findings = rule.analyzeProject(projectPath: tempDir.path);

      expect(findings.length, equals(1));
      expect(findings.first.id, equals('UI_ASSET_MISSING_FILE'));
      expect(findings.first.severity, equals(DiagnosticSeverity.error));
      expect(findings.first.summary, contains('missing_logo.png'));
    });

    test('UI_ASSET_CASE_MISMATCH detects casing differences on disk', () async {
      final pubspecFile = File('${tempDir.path}${Platform.pathSeparator}pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_app
flutter:
  assets:
    - assets/images/Logo.png
''');

      final imgDir = Directory('${tempDir.path}${Platform.pathSeparator}assets${Platform.pathSeparator}images');
      await imgDir.create(recursive: true);
      final imgFile = File('${imgDir.path}${Platform.pathSeparator}logo.png');
      await imgFile.writeAsString('dummy img');

      const rule = AssetCaseMismatchRule();
      final findings = rule.analyzeProject(projectPath: tempDir.path);

      expect(findings.length, equals(1));
      expect(findings.first.id, equals('UI_ASSET_CASE_MISMATCH'));
      expect(findings.first.severity, equals(DiagnosticSeverity.warning));
    });

    test('UI_ASSET_OVERSIZED flags image files larger than size threshold', () async {
      final pubspecFile = File('${tempDir.path}${Platform.pathSeparator}pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_app
flutter:
  assets:
    - assets/large.png
''');

      final largeFile = File('${tempDir.path}${Platform.pathSeparator}assets${Platform.pathSeparator}large.png');
      await largeFile.create(recursive: true);
      // Write 2.5 MB of data
      final bytes = List<int>.filled(2500000, 0);
      await largeFile.writeAsBytes(bytes);

      const rule = AssetOversizedRule(maxSizeBytes: 2000000);
      final findings = rule.analyzeProject(projectPath: tempDir.path);

      expect(findings.length, equals(1));
      expect(findings.first.id, equals('UI_ASSET_OVERSIZED'));
      expect(findings.first.summary, contains('large.png'));
    });

    test('UI_DEBUG_PRINT_IN_PROD flags print and debugPrint calls', () {
      const source = '''
import 'package:flutter/foundation.dart';

void logData() {
  debugPrint("debug log message");
  print("raw print statement");
}
''';
      final ast = parseString(content: source).unit;
      const rule = DebugPrintInProdRule();

      final findings = rule.analyzeDartFile(
        filePath: '/lib/main.dart',
        relativePath: 'lib/main.dart',
        content: source,
        ast: ast,
      );

      expect(findings.length, equals(2));
      expect(findings.map((f) => f.id), everyElement(equals('UI_DEBUG_PRINT_IN_PROD')));
    });

    test('UI_LARGE_BUILD_METHOD flags build methods exceeding line threshold', () {
      final lines = List<String>.generate(120, (i) => '    final item$i = $i;');
      final source = '''
import 'package:flutter/material.dart';

class MyLargeWidget extends StatelessWidget {
  const MyLargeWidget({super.key});

  @override
  Widget build(BuildContext context) {
${lines.join('\n')}
    return Container();
  }
}
''';
      final ast = parseString(content: source).unit;
      const rule = LargeBuildMethodRule(maxLines: 100);

      final findings = rule.analyzeDartFile(
        filePath: '/lib/widget.dart',
        relativePath: 'lib/widget.dart',
        content: source,
        ast: ast,
      );

      expect(findings.length, equals(1));
      expect(findings.first.id, equals('UI_LARGE_BUILD_METHOD'));
      expect(findings.first.summary, contains('MyLargeWidget'));
    });

    test('UI_SHRINKWRAP_IN_SCROLLABLE flags shrinkWrap: true inside scrollable ancestor', () {
      const source = '''
import 'package:flutter/material.dart';

Widget buildList() {
  return SingleChildScrollView(
    child: ListView(
      shrinkWrap: true,
      children: const [],
    ),
  );
}
''';
      final ast = parseString(content: source).unit;
      const rule = ShrinkWrapInScrollableRule();

      final findings = rule.analyzeDartFile(
        filePath: '/lib/list.dart',
        relativePath: 'lib/list.dart',
        content: source,
        ast: ast,
      );

      expect(findings.length, equals(1));
      expect(findings.first.id, equals('UI_SHRINKWRAP_IN_SCROLLABLE'));
    });

    test('UI_ACCESSIBILITY_MISSING_IMAGE_SEMANTICS flags Image calls without label', () {
      const source = '''
import 'package:flutter/material.dart';

Widget buildImage() {
  return Image.asset('assets/icon.png');
}
''';
      final ast = parseString(content: source).unit;
      const rule = AccessibilityMissingImageSemanticsRule();

      final findings = rule.analyzeDartFile(
        filePath: '/lib/img.dart',
        relativePath: 'lib/img.dart',
        content: source,
        ast: ast,
      );

      expect(findings.length, equals(1));
      expect(findings.first.id, equals('UI_ACCESSIBILITY_MISSING_IMAGE_SEMANTICS'));
    });
  });
}
