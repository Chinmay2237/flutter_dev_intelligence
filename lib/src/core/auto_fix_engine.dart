import 'dart:io';
import '../ui_doctor/ast_parser.dart';
import 'models.dart';

/// Result of an automated fix planning or application run.
class AutoFixResult {
  const AutoFixResult({
    required this.success,
    required this.modifiedFiles,
    required this.backupFiles,
    required this.diffs,
    required this.skipped,
    required this.message,
  });

  final bool success;
  final List<String> modifiedFiles;
  final List<String> backupFiles;
  final List<String> diffs;
  final List<String> skipped;
  final String message;

  Map<String, dynamic> toJson() => {
    'success': success,
    'modifiedFiles': modifiedFiles,
    'backupFiles': backupFiles,
    'diffs': diffs,
    'skipped': skipped,
    'message': message,
  };
}

/// Engine for safely planning and applying automated fix suggestions.
class AutoFixEngine {
  const AutoFixEngine._();

  /// Plans automated fixes without modifying any project files (dry-run mode).
  static AutoFixResult planFixes(
    List<DiagnosticIssue> issues, {
    String? projectRootPath,
  }) {
    final diffs = <String>[];
    final skipped = <String>[];
    final targetFiles = <String>[];

    for (final issue in issues) {
      for (final suggestion in issue.suggestions) {
        final path = issue.filePath;
        if (!_isEligibleForAutoFix(
          issue: issue,
          suggestion: suggestion,
          path: path,
          projectRootPath: projectRootPath,
          skipped: skipped,
        )) {
          continue;
        }

        targetFiles.add(path!);
        diffs.add('--- $path\n+++ $path\n${suggestion.proposedChange}');
      }
    }

    return AutoFixResult(
      success: true,
      modifiedFiles: targetFiles.toSet().toList(),
      backupFiles: const [],
      diffs: diffs,
      skipped: skipped,
      message:
          'Planned ${diffs.length} safe fix(es) (${skipped.length} skipped). Dry-run completed without disk modifications.',
    );
  }

  /// Applies safe automated fixes to project files with explicit safety guardrails and syntax validation.
  static Future<AutoFixResult> applyFixes(
    List<DiagnosticIssue> issues, {
    bool createBackups = true,
    bool dryRun = false,
    bool allowHighRisk = false,
    String? projectRootPath,
  }) async {
    if (dryRun) {
      return planFixes(issues, projectRootPath: projectRootPath);
    }

    final modifiedFiles = <String>[];
    final backupFiles = <String>[];
    final diffs = <String>[];
    final skipped = <String>[];
    var anyFailures = false;

    for (final issue in issues) {
      for (final suggestion in issue.suggestions) {
        final path = issue.filePath;

        if (suggestion.riskLevel == FixRiskLevel.high && !allowHighRisk) {
          skipped.add(
            'Skipped high-risk fix for ${issue.id}: ${suggestion.action} (requires explicit high-risk confirmation flag).',
          );
          continue;
        }

        if (!_isEligibleForAutoFix(
          issue: issue,
          suggestion: suggestion,
          path: path,
          projectRootPath: projectRootPath,
          skipped: skipped,
        )) {
          continue;
        }

        final file = File(path!);
        if (!await file.exists()) {
          skipped.add(
            'Skipped fix for ${issue.id}: Target file $path does not exist.',
          );
          continue;
        }

        String? backupPath;
        try {
          final originalContent = await file.readAsString();
          final updatedContent = _applyChange(
            originalContent,
            suggestion.proposedChange!,
          );

          if (updatedContent == originalContent) {
            skipped.add(
              'Skipped fix for ${issue.id}: No content changes produced by proposed diff.',
            );
            continue;
          }

          // AST Syntax Validation for Dart files
          if (path.endsWith('.dart')) {
            final parseResult = AstParser.parse(updatedContent, filePath: path);
            if (parseResult.parseErrors.isNotEmpty) {
              anyFailures = true;
              skipped.add(
                'Skipped fix for ${issue.id} on $path: Proposed fix produced invalid Dart syntax (${parseResult.parseErrors.first}).',
              );
              continue;
            }
          }

          if (createBackups) {
            backupPath = '$path.bak';
            await file.copy(backupPath);
            backupFiles.add(backupPath);
          }

          try {
            await file.writeAsString(updatedContent);
            modifiedFiles.add(path);
            diffs.add('--- $path\n+++ $path\n${suggestion.proposedChange}');
          } catch (writeError) {
            anyFailures = true;
            if (backupPath != null && await File(backupPath).exists()) {
              await File(backupPath).copy(path);
            }
            skipped.add(
              'Failed to apply fix for ${issue.id} on $path (rolled back original file): $writeError',
            );
          }
        } catch (readError) {
          anyFailures = true;
          skipped.add('Failed to read target file $path: $readError');
        }
      }
    }

    return AutoFixResult(
      success: !anyFailures,
      modifiedFiles: modifiedFiles.toSet().toList(),
      backupFiles: backupFiles,
      diffs: diffs,
      skipped: skipped,
      message:
          'Applied ${modifiedFiles.length} fix(es) (${skipped.length} skipped).',
    );
  }

  static bool _isEligibleForAutoFix({
    required DiagnosticIssue issue,
    required FixSuggestion suggestion,
    required String? path,
    required String? projectRootPath,
    required List<String> skipped,
  }) {
    if (!suggestion.isSafeToAutomate || suggestion.requiresUserConfirmation) {
      skipped.add(
        'Skipped unsafe fix for ${issue.id}: ${suggestion.action} (requires user confirmation)',
      );
      return false;
    }

    if (path == null ||
        suggestion.proposedChange == null ||
        suggestion.proposedChange!.trim().isEmpty) {
      skipped.add(
        'Skipped fix for ${issue.id}: Missing target file path or proposed diff.',
      );
      return false;
    }

    if (_hasPathTraversal(path)) {
      skipped.add(
        'Skipped fix for ${issue.id}: Path traversal detected in target path: $path.',
      );
      return false;
    }

    if (projectRootPath != null &&
        !_isWithinProjectRoot(path, projectRootPath)) {
      skipped.add(
        'Skipped fix for ${issue.id}: Target file $path is outside project root $projectRootPath.',
      );
      return false;
    }

    if (_isSensitiveOrGenerated(path)) {
      skipped.add(
        'Skipped fix for ${issue.id}: Refusing to modify generated or sensitive file $path.',
      );
      return false;
    }

    return true;
  }

  static bool _hasPathTraversal(String path) {
    return path.contains('..') ||
        path.contains('/../') ||
        path.contains('\\..\\');
  }

  static bool _isWithinProjectRoot(String path, String projectRoot) {
    final normalizedPath = File(path).absolute.path;
    final normalizedRoot = Directory(projectRoot).absolute.path;
    return normalizedPath.startsWith(normalizedRoot);
  }

  static bool _isSensitiveOrGenerated(String path) {
    final lower = path.toLowerCase();
    final fileName = path.split(Platform.pathSeparator).last.toLowerCase();

    if (lower.endsWith('.g.dart') ||
        lower.endsWith('.freezed.dart') ||
        lower.endsWith('.config.dart') ||
        lower.endsWith('.mocks.dart') ||
        lower.contains('/generated/') ||
        lower.contains('/build/') ||
        lower.contains('/.dart_tool/')) {
      return true;
    }

    if (lower.contains('.env') ||
        lower.contains('.git/') ||
        lower.endsWith('.git') ||
        fileName == 'pubspec.lock' ||
        fileName == 'credentials.json' ||
        fileName == 'service-account.json' ||
        fileName == 'id_rsa' ||
        fileName.endsWith('.pem') ||
        fileName.endsWith('.jks') ||
        fileName.endsWith('.keystore') ||
        fileName.endsWith('.p12')) {
      return true;
    }

    return false;
  }

  static String _applyChange(String originalContent, String proposedChange) {
    final lines = proposedChange.split('\n');
    var result = originalContent;
    for (final line in lines) {
      if (line.startsWith('- ') && !line.startsWith('---')) {
        final removeText = line.substring(2);
        result = result.replaceAll(removeText, '');
      } else if (line.startsWith('+ ') && !line.startsWith('+++')) {
        final addText = line.substring(2);
        result = '$result\n$addText';
      }
    }
    return result;
  }
}
