import 'dart:convert';
import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('UI Doctor Engine & CLI Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ui_doctor_cli_test_');

      // Create valid mini Flutter project layout
      final pubspec = File(
        '${tempDir.path}${Platform.pathSeparator}pubspec.yaml',
      );
      await pubspec.writeAsString('''
name: sample_flutter_app
description: Sample app for testing UI Doctor CLI
version: 1.0.0
environment:
  sdk: ^3.0.0
flutter:
  assets:
    - assets/missing_file.png
''');

      final libDir = Directory('${tempDir.path}${Platform.pathSeparator}lib');
      await libDir.create(recursive: true);

      final mainDart = File('${libDir.path}${Platform.pathSeparator}main.dart');
      await mainDart.writeAsString('''
import 'package:flutter/material.dart';

void main() {
  print("Main started");
}

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/missing_file.png');
  }
}
''');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'UiDoctorEngine runs all rules and returns diagnostic report',
      () async {
        final report = await UiDoctorEngine.analyze(
          UiDoctorEngineOptions(projectPath: tempDir.path),
        );

        expect(report.projectName, equals('sample_flutter_app'));
        expect(report.commandName, equals('ui-doctor'));
        expect(report.findings, isNotEmpty);

        final findingIds = report.findings.map((f) => f.id).toSet();
        expect(findingIds, contains('UI_ASSET_MISSING_FILE'));
        expect(findingIds, contains('UI_DEBUG_PRINT_IN_PROD'));
        expect(
          findingIds,
          contains('UI_ACCESSIBILITY_MISSING_IMAGE_SEMANTICS'),
        );
      },
    );

    test('UiDoctorEngine respects --scope filtering', () async {
      final report = await UiDoctorEngine.analyze(
        UiDoctorEngineOptions(projectPath: tempDir.path, scope: 'assets'),
      );

      expect(report.findings, isNotEmpty);
      expect(
        report.findings.every((f) => f.id.startsWith('UI_ASSET_')),
        isTrue,
      );
    });

    test(
      'UiDoctorCli outputs JSON format when --format=json is specified',
      () async {
        final outputFile = File(
          '${tempDir.path}${Platform.pathSeparator}report.json',
        );

        final exitCode = await UiDoctorCli.run([
          '--project=${tempDir.path}',
          '--format=json',
          '--output=${outputFile.path}',
          '--quiet',
        ]);

        // Returns exit code 1 because UI_ASSET_MISSING_FILE is DiagnosticSeverity.error
        expect(exitCode, equals(1));
        expect(outputFile.existsSync(), isTrue);

        final jsonContent = await outputFile.readAsString();
        final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;

        expect(decoded['commandName'], equals('ui-doctor'));
        expect(decoded['findings'], isA<List>());
      },
    );

    test(
      'UiDoctorCli outputs Markdown format when --format=markdown is specified',
      () async {
        final outputFile = File(
          '${tempDir.path}${Platform.pathSeparator}report.md',
        );

        await UiDoctorCli.run([
          '--project=${tempDir.path}',
          '--format=markdown',
          '--output=${outputFile.path}',
          '--quiet',
        ]);

        expect(outputFile.existsSync(), isTrue);
        final mdContent = await outputFile.readAsString();
        expect(
          mdContent,
          contains('# Flutter Dev Intelligence Diagnostic Report'),
        );
        expect(mdContent, contains('UI_ASSET_MISSING_FILE'));
      },
    );
  });
}
