import 'dart:convert';
import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('UI Doctor Refined Rules & Baseline Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'ui_doctor_baseline_test_',
      );

      // Copy fixture layout to tempDir
      final pubspec = File(
        '${tempDir.path}${Platform.pathSeparator}pubspec.yaml',
      );
      await pubspec.writeAsString('''
name: temp_fixture_app
version: 1.0.0
flutter:
  assets:
    - assets/missing_file.png
''');

      final libDir = Directory('${tempDir.path}${Platform.pathSeparator}lib');
      await libDir.create(recursive: true);

      final mainDart = File('${libDir.path}${Platform.pathSeparator}main.dart');
      await mainDart.writeAsString('''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  if (kDebugMode) {
    debugPrint("Guarded log");
  }
  print("Raw unguarded print");
}

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Image.asset('assets/missing_file.png'),
          Image.asset('assets/decorative.png', excludeFromSemantics: true),
          ListView(
            shrinkWrap: true,
            children: const [],
          ),
        ],
      ),
    );
  }
}
''');

      final testDir = Directory('${tempDir.path}${Platform.pathSeparator}test');
      await testDir.create(recursive: true);
      final testFile = File(
        '${testDir.path}${Platform.pathSeparator}widget_test.dart',
      );
      await testFile.writeAsString('void main() { print("test file print"); }');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'Engine ignores kDebugMode guarded prints and respects excludeFromSemantics',
      () async {
        final report = await UiDoctorEngine.analyze(
          UiDoctorEngineOptions(projectPath: tempDir.path),
        );

        final debugFindings = report.findings
            .where((f) => f.id == 'UI_DEBUG_PRINT_IN_PROD')
            .toList();
        expect(debugFindings.length, equals(1));
        expect(debugFindings.first.summary, contains('print'));

        final imageFindings = report.findings
            .where((f) => f.id == 'UI_ACCESSIBILITY_MISSING_IMAGE_SEMANTICS')
            .toList();
        expect(imageFindings.first.summary, contains('Image.asset'));
        expect(imageFindings.first.line, equals(19));
      },
    );

    test('CLI --generate-baseline saves baseline JSON snapshot', () async {
      final baselineFile = File(
        '${tempDir.path}${Platform.pathSeparator}baseline.json',
      );

      final exitCode = await UiDoctorCli.run([
        '--project=${tempDir.path}',
        '--generate-baseline=${baselineFile.path}',
        '--quiet',
      ]);

      expect(exitCode, equals(0));
      expect(baselineFile.existsSync(), isTrue);

      final jsonContent = await baselineFile.readAsString();
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
      expect(decoded['findings'], isA<List>());
    });

    test('CLI --baseline compares snapshot and flags new issues', () async {
      final baselineFile = File(
        '${tempDir.path}${Platform.pathSeparator}baseline.json',
      );

      // 1. Generate baseline
      await UiDoctorCli.run([
        '--project=${tempDir.path}',
        '--generate-baseline=${baselineFile.path}',
        '--quiet',
      ]);

      // 2. Run baseline comparison on clean state -> PASSED
      final passExitCode = await UiDoctorCli.run([
        '--project=${tempDir.path}',
        '--baseline=${baselineFile.path}',
        '--quiet',
      ]);
      expect(
        passExitCode,
        equals(1),
      ); // Has error finding UI_ASSET_MISSING_FILE, but no new baseline findings

      // 3. Add a NEW flaw to lib/main.dart
      final mainDart = File(
        '${tempDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
      );
      final currentContent = await mainDart.readAsString();
      await mainDart.writeAsString(
        '$currentContent\nvoid anotherFunc() { print("new raw print"); }\n',
      );

      // 4. Run baseline comparison -> detects new finding
      final baselineReportFile = File(
        '${tempDir.path}${Platform.pathSeparator}diff_report.json',
      );
      final failExitCode = await UiDoctorCli.run([
        '--project=${tempDir.path}',
        '--baseline=${baselineFile.path}',
        '--format=json',
        '--output=${baselineReportFile.path}',
        '--quiet',
      ]);

      expect(failExitCode, equals(1));
      expect(baselineReportFile.existsSync(), isTrue);

      final decodedReport =
          jsonDecode(await baselineReportFile.readAsString())
              as Map<String, dynamic>;
      expect(decodedReport['baseline'], isNotNull);
      expect(decodedReport['baseline']['status'], equals('FAILED'));
      expect(decodedReport['baseline']['newCount'], greaterThanOrEqualTo(1));
    });
  });
}
