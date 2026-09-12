@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

class FailingAiProvider implements AiProvider {
  @override
  Future<AiResponse> analyze(AiRequest request) async {
    throw Exception('Simulated network error or API failure');
  }
}

class TimeoutAiProvider implements AiProvider {
  @override
  Future<AiResponse> analyze(AiRequest request) async {
    await Future<void>.delayed(const Duration(seconds: 15));
    return const AiResponse(
      summary: 'Delayed response',
      probableCauses: [],
      suggestions: [],
      confidence: 1.0,
    );
  }
}

void main() {
  group('Phase 10 — Security, Privacy, AI, & Auto-Fix Hardening', () {
    group('1. Secret Redaction Pipeline', () {
      test('redacts private RSA and SSH keys', () {
        const key = '''
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0Z1234567890abcdef...
-----END RSA PRIVATE KEY-----
''';
        final redacted = SecretRedactor.redact(key);
        expect(redacted, contains('[REDACTED_PRIVATE_KEY]'));
        expect(redacted, isNot(contains('MIIEowIBAAKCAQEA0Z')));
      });

      test('redacts JWT tokens and Bearer headers', () {
        const input =
            'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        final redacted = SecretRedactor.redact(input);
        expect(redacted, contains('[REDACTED]'));
        expect(
          redacted,
          isNot(contains('SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')),
        );
      });

      test('redacts GitHub and GitLab tokens', () {
        const input =
            'token=ghp_1234567890abcdefghijklmnopqrstuvwxyz glpat-abcdefghijklmnopqrst';
        final redacted = SecretRedactor.redact(input);
        expect(redacted, contains('[REDACTED_GITHUB_TOKEN]'));
        expect(redacted, contains('[REDACTED_GITLAB_TOKEN]'));
      });

      test('redacts AWS, GCP, and OpenAI API keys', () {
        const input =
            'AWS=AKIA1234567890ABCDEF GCP=AIzaSyA1234567890123456789012345678 OPENAI=sk-1234567890abcdef1234567890';
        final redacted = SecretRedactor.redact(input);
        expect(redacted, contains('[REDACTED_AWS_KEY]'));
        expect(redacted, contains('[REDACTED_GCP_KEY]'));
        expect(redacted, contains('[REDACTED_OPENAI_KEY]'));
      });

      test('redacts embedded credentials in URLs', () {
        const url = 'https://admin:secretPass123@api.my-domain.com/v1/data';
        final redacted = SecretRedactor.redact(url);
        expect(
          redacted,
          contains('https://[REDACTED]@api.my-domain.com/v1/data'),
        );
        expect(redacted, isNot(contains('secretPass123')));
      });

      test('redacts Android Keystore passwords and user paths', () {
        const input =
            'storePassword=myKeystorePass123 path=/home/chinmay/projects/app';
        final redacted = SecretRedactor.redact(input);
        expect(redacted, contains('storePassword=[REDACTED]'));
        expect(redacted, contains('~/projects/app'));
      });
    });

    group('2. AI Provider Resiliency & Privacy Isolation', () {
      test('AI analysis returns null when disabled by default', () async {
        const service = AiAnalysisService(
          config: AiProviderConfig(enabled: false),
        );
        final response = await service.analyze(
          const AiRequest(category: 'build', summary: 'test', evidence: []),
        );
        expect(response, isNull);
      });

      test(
        'AI provider failure is caught safely without throwing exception',
        () async {
          final service = AiAnalysisService(
            config: const AiProviderConfig(enabled: true),
            provider: FailingAiProvider(),
          );

          final response = await service.analyze(
            const AiRequest(category: 'build', summary: 'test', evidence: []),
          );

          expect(response, isNotNull);
          expect(response!.confidence, 0.0);
          expect(response.summary, contains('AI Provider request failed'));
        },
      );

      test('AI provider timeout returns advisory failure response', () async {
        final service = AiAnalysisService(
          config: const AiProviderConfig(
            enabled: true,
            timeoutDuration: Duration(milliseconds: 100),
          ),
          provider: TimeoutAiProvider(),
        );

        final response = await service.analyze(
          const AiRequest(category: 'build', summary: 'test', evidence: []),
        );

        expect(response, isNotNull);
        expect(response!.confidence, 0.0);
        expect(response.summary, contains('failed or timed out'));
      });
    });

    group('3. Safe Auto-Fix Engine & AST Syntax Validation', () {
      test(
        'planFixes operates in dry-run mode without modifying files on disk',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'autofix_dryrun_',
          );
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final targetFile = File('${tempDir.path}/main.dart');
          const originalCode = 'class App {}';
          await targetFile.writeAsString(originalCode);

          final issue = DiagnosticIssue(
            id: 'ui.sample-fix',
            category: DiagnosticCategory.layout,
            severity: DiagnosticSeverity.low,
            title: 'Sample fixable issue',
            description: 'Sample issue description',
            filePath: targetFile.path,
            suggestions: const [
              FixSuggestion(
                action: 'Add const prefix',
                details: 'Details for const prefix fix suggestion.',
                proposedChange: '- class App {}\n+ const class App {}',
                isSafeToAutomate: true,
                requiresUserConfirmation: false,
                riskLevel: FixRiskLevel.low,
              ),
            ],
          );

          final planResult = AutoFixEngine.planFixes([
            issue,
          ], projectRootPath: tempDir.path);
          expect(planResult.success, isTrue);
          expect(planResult.diffs, isNotEmpty);
          expect(
            await targetFile.readAsString(),
            originalCode,
          ); // Disk un-mutated!
        },
      );

      test('rejects path traversal attempts outside project root', () {
        const traversalIssue = DiagnosticIssue(
          id: 'ui.path-traversal',
          category: DiagnosticCategory.layout,
          severity: DiagnosticSeverity.high,
          title: 'Path traversal attempt',
          description: 'Attempting fix outside root',
          filePath: '/tmp/../../etc/passwd',
          suggestions: [
            FixSuggestion(
              action: 'Malicious path change',
              details: 'Details for path traversal test.',
              proposedChange: '+ root:x:0:0:',
              isSafeToAutomate: true,
              requiresUserConfirmation: false,
            ),
          ],
        );

        final result = AutoFixEngine.planFixes([
          traversalIssue,
        ], projectRootPath: '/tmp/my_app');
        expect(result.modifiedFiles, isEmpty);
        expect(result.skipped.first, contains('Path traversal detected'));
      });

      test(
        'refuses to modify sensitive or generated files (.env, pubspec.lock, .g.dart)',
        () {
          const sensitiveIssue = DiagnosticIssue(
            id: 'env.secret',
            category: DiagnosticCategory.build,
            severity: DiagnosticSeverity.high,
            title: 'Env modification attempt',
            description: 'Refusing env changes',
            filePath: '/project/.env',
            suggestions: [
              FixSuggestion(
                action: 'Update .env file',
                details: 'Details for sensitive file test.',
                proposedChange: '+ SECRET=abc',
                isSafeToAutomate: true,
                requiresUserConfirmation: false,
              ),
            ],
          );

          final result = AutoFixEngine.planFixes([
            sensitiveIssue,
          ], projectRootPath: '/project');
          expect(result.modifiedFiles, isEmpty);
          expect(
            result.skipped.first,
            contains('Refusing to modify generated or sensitive file'),
          );
        },
      );

      test(
        'AST syntax validation aborts and skips fix when proposed diff produces invalid Dart syntax',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'autofix_syntax_',
          );
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final targetFile = File('${tempDir.path}/broken.dart');
          const validSource = '''
import 'package:flutter/widgets.dart';

Widget buildWidget() => const SizedBox();
''';
          await targetFile.writeAsString(validSource);

          final brokenFixIssue = DiagnosticIssue(
            id: 'ui.broken-syntax',
            category: DiagnosticCategory.layout,
            severity: DiagnosticSeverity.medium,
            title: 'Broken diff syntax test',
            description: 'Diff that produces unparseable syntax',
            filePath: targetFile.path,
            suggestions: const [
              FixSuggestion(
                action: 'Break Dart syntax',
                details: 'Details for broken syntax test.',
                proposedChange: '+ class {{{ broken syntax @!#\$',
                isSafeToAutomate: true,
                requiresUserConfirmation: false,
                riskLevel: FixRiskLevel.low,
              ),
            ],
          );

          final applyResult = await AutoFixEngine.applyFixes([
            brokenFixIssue,
          ], projectRootPath: tempDir.path);

          expect(applyResult.success, isFalse);
          expect(applyResult.modifiedFiles, isEmpty);
          expect(
            applyResult.skipped.first,
            contains('Proposed fix produced invalid Dart syntax'),
          );
          expect(
            await targetFile.readAsString(),
            validSource,
          ); // Rolled back cleanly!
        },
      );
    });
  });
}
