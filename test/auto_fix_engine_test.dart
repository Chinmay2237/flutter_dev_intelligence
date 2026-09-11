import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 7 AutoFixEngine Safety Verification Tests', () {
    test('1. Dry-run planning generates diffs without touching disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('autofix_dryrun_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final targetFile = File('${tempDir.path}/widget.dart');
      await targetFile.writeAsString('class TestWidget {}');

      final issue = DiagnosticIssue(
        id: 'ui_expanded_misuse',
        category: DiagnosticCategory.layout,
        severity: DiagnosticSeverity.high,
        title: 'Expanded misuse',
        description: 'Expanded used outside Flex',
        filePath: targetFile.path,
        suggestions: [
          const FixSuggestion(
            action: 'Remove Expanded wrapper',
            details: 'Replace Expanded with child',
            riskLevel: FixRiskLevel.low,
            proposedChange: '- Expanded(\n+ SizedBox(',
            isSafeToAutomate: true,
            requiresUserConfirmation: false,
          ),
          const FixSuggestion(
            action: 'Manual refactor required',
            details: 'Requires human architectural decision',
            riskLevel: FixRiskLevel.high,
            proposedChange: null,
            isSafeToAutomate: false,
            requiresUserConfirmation: true,
          ),
        ],
      );

      final result = AutoFixEngine.planFixes([issue]);

      expect(result.success, isTrue);
      expect(result.diffs.length, 1);
      expect(result.diffs.first, contains('--- ${targetFile.path}'));
      expect(result.diffs.first, contains('+++ ${targetFile.path}'));
      expect(result.diffs.first, contains('- Expanded('));
      expect(result.skipped.length, 1);
      expect(result.skipped.first, contains('Skipped unsafe fix'));
      expect(await targetFile.readAsString(), equals('class TestWidget {}'));
    });

    test(
      '2. applyFixes creates .bak backup file and modifies target safely',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('autofix_apply_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final targetFile = File('${tempDir.path}/widget.dart');
        await targetFile.writeAsString(
          'class MyWidget extends StatelessWidget {\n  // old_code\n}',
        );

        final issue = DiagnosticIssue(
          id: 'clean_comment',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.low,
          title: 'Legacy code comment',
          description: 'Remove legacy comment',
          filePath: targetFile.path,
          suggestions: [
            const FixSuggestion(
              action: 'Remove legacy comment',
              details: 'Remove old_code line',
              proposedChange: '- // old_code',
              isSafeToAutomate: true,
              requiresUserConfirmation: false,
            ),
          ],
        );

        final result = await AutoFixEngine.applyFixes([
          issue,
        ], createBackups: true);

        expect(result.success, isTrue);
        expect(result.modifiedFiles, contains(targetFile.path));
        expect(result.backupFiles, contains('${targetFile.path}.bak'));

        final backupFile = File('${targetFile.path}.bak');
        expect(backupFile.existsSync(), isTrue);
        expect(await backupFile.readAsString(), contains('// old_code'));

        final modifiedContent = await targetFile.readAsString();
        expect(modifiedContent, isNot(contains('// old_code')));
      },
    );

    test('3. Refuses to modify sensitive or credential files', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'autofix_sensitive_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final envFile = File('${tempDir.path}/.env');
      await envFile.writeAsString('SECRET_KEY=12345');

      final lockFile = File('${tempDir.path}/pubspec.lock');
      await lockFile.writeAsString('packages: {}');

      final issue1 = DiagnosticIssue(
        id: 'env_secret',
        category: DiagnosticCategory.build,
        severity: DiagnosticSeverity.high,
        title: 'Secret key in env',
        description: 'Secret detected in environment file',
        filePath: envFile.path,
        suggestions: [
          const FixSuggestion(
            action: 'Modify env file',
            details: 'Edit env file',
            proposedChange: '- SECRET_KEY=12345',
            isSafeToAutomate: true,
            requiresUserConfirmation: false,
          ),
        ],
      );

      final issue2 = DiagnosticIssue(
        id: 'lock_issue',
        category: DiagnosticCategory.build,
        severity: DiagnosticSeverity.medium,
        title: 'Lock issue',
        description: 'Lockfile issue detected',
        filePath: lockFile.path,
        suggestions: [
          const FixSuggestion(
            action: 'Modify lock file',
            details: 'Edit lock file',
            proposedChange: '- packages: {}',
            isSafeToAutomate: true,
            requiresUserConfirmation: false,
          ),
        ],
      );

      final result = await AutoFixEngine.applyFixes([issue1, issue2]);

      expect(result.modifiedFiles, isEmpty);
      expect(result.skipped.length, 2);
      expect(
        result.skipped.every(
          (s) => s.contains('Refusing to modify generated or sensitive file'),
        ),
        isTrue,
      );
    });

    test(
      '4. Refuses generated files (.g.dart, .freezed.dart, build/)',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('autofix_gen_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final genFile = File('${tempDir.path}/model.g.dart');
        await genFile.writeAsString('// generated');

        final freezedFile = File('${tempDir.path}/model.freezed.dart');
        await freezedFile.writeAsString('// freezed');

        final issue = DiagnosticIssue(
          id: 'gen_issue',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.low,
          title: 'Generated issue',
          description: 'Generated file warning',
          filePath: genFile.path,
          suggestions: [
            const FixSuggestion(
              action: 'Edit gen file',
              details: 'Edit model.g.dart',
              proposedChange: '- // generated',
              isSafeToAutomate: true,
              requiresUserConfirmation: false,
            ),
          ],
        );

        final result = await AutoFixEngine.applyFixes([issue]);

        expect(result.modifiedFiles, isEmpty);
        expect(
          result.skipped.first,
          contains('Refusing to modify generated or sensitive file'),
        );
      },
    );

    test('5. Rejects path traversal attempts and out-of-root paths', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'autofix_traversal_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final issueTraversal = DiagnosticIssue(
        id: 'traversal_issue',
        category: DiagnosticCategory.build,
        severity: DiagnosticSeverity.high,
        title: 'Path traversal test',
        description: 'Path traversal attempt detected',
        filePath: '${tempDir.path}/../outside.dart',
        suggestions: [
          const FixSuggestion(
            action: 'Traversal fix',
            details: 'Attempt traversal',
            proposedChange: '- bad\n+ good',
            isSafeToAutomate: true,
            requiresUserConfirmation: false,
          ),
        ],
      );

      final result = AutoFixEngine.planFixes([
        issueTraversal,
      ], projectRootPath: tempDir.path);

      expect(result.modifiedFiles, isEmpty);
      expect(result.skipped.first, contains('Path traversal detected'));
    });

    test('6. High-risk fixes require explicit confirmation flag', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'autofix_highrisk_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final targetFile = File('${tempDir.path}/main.dart');
      await targetFile.writeAsString('void main() {}');

      final issue = DiagnosticIssue(
        id: 'high_risk_issue',
        category: DiagnosticCategory.architecture,
        severity: DiagnosticSeverity.high,
        title: 'High risk refactor',
        description: 'High risk refactoring suggested',
        filePath: targetFile.path,
        suggestions: [
          const FixSuggestion(
            action: 'Major structural change',
            details: 'Refactor main function',
            riskLevel: FixRiskLevel.high,
            proposedChange:
                '- void main() {}\n+ void main() { runApp(App()); }',
            isSafeToAutomate: true,
            requiresUserConfirmation: false,
          ),
        ],
      );

      final resultWithoutFlag = await AutoFixEngine.applyFixes([
        issue,
      ], allowHighRisk: false);
      expect(resultWithoutFlag.modifiedFiles, isEmpty);
      expect(
        resultWithoutFlag.skipped.first,
        contains('requires explicit high-risk confirmation flag'),
      );

      final resultWithFlag = await AutoFixEngine.applyFixes([
        issue,
      ], allowHighRisk: true);
      expect(resultWithFlag.modifiedFiles, contains(targetFile.path));
    });

    test('7. Handles no-op content changes cleanly', () async {
      final tempDir = await Directory.systemTemp.createTemp('autofix_noop_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final targetFile = File('${tempDir.path}/widget.dart');
      await targetFile.writeAsString('class Widget {}');

      final issue = DiagnosticIssue(
        id: 'noop_issue',
        category: DiagnosticCategory.build,
        severity: DiagnosticSeverity.low,
        title: 'Noop change',
        description: 'Noop edit test',
        filePath: targetFile.path,
        suggestions: [
          const FixSuggestion(
            action: 'Noop edit',
            details: 'Replace non-existent string',
            proposedChange: '- non_existent_string',
            isSafeToAutomate: true,
            requiresUserConfirmation: false,
          ),
        ],
      );

      final result = await AutoFixEngine.applyFixes([issue]);
      expect(result.modifiedFiles, isEmpty);
      expect(
        result.skipped.first,
        contains('No content changes produced by proposed diff'),
      );
    });
  });
}
