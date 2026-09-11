import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 6 Privacy and AI Boundary Tests', () {
    test(
      'PrivacyRedactor masks API keys, bearer tokens, credentials, and paths',
      () {
        final text = '''
api_key=sk-123456789012345678901234
Authorization: Bearer mySecretToken123456
Url: https://admin:pass123@internal.example.com/data
AWS: AKIAIOSFODNN7EXAMPLE
GCP: AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P
Path: /home/john_doe/Projects/flutter_app/lib/main.dart
PathMac: /Users/alice/Projects/flutter_app/lib/main.dart
''';

        final redacted = PrivacyRedactor.redact(text);

        expect(redacted, contains('api_key=[REDACTED]'));
        expect(redacted, contains('Authorization: Bearer [REDACTED]'));
        expect(
          redacted,
          contains('https://[REDACTED]@internal.example.com/data'),
        );
        expect(redacted, contains('[REDACTED_AWS_KEY]'));
        expect(redacted, contains('[REDACTED_GCP_KEY]'));
        expect(
          redacted,
          contains('Path: ~/Projects/flutter_app/lib/main.dart'),
        );
        expect(
          redacted,
          contains('PathMac: ~/Projects/flutter_app/lib/main.dart'),
        );
      },
    );

    test('AiAnalysisService returns null when disabled by default', () async {
      const service = AiAnalysisService(
        config: AiProviderConfig(enabled: false),
        provider: MockAiProvider(),
      );

      const request = AiRequest(
        category: 'build',
        summary: 'Build failure with secret api_key=12345',
        evidence: ['Line 1', 'Line 2'],
      );

      final response = await service.analyze(request);
      expect(response, isNull);
    });

    test('AiAnalysisService redacts request payload when enabled', () async {
      late AiRequest capturedRequest;

      final testProvider = _CapturingAiProvider((req) {
        capturedRequest = req;
      });

      final service = AiAnalysisService(
        config: const AiProviderConfig(
          enabled: true,
          redactBeforeTransmission: true,
        ),
        provider: testProvider,
      );

      const request = AiRequest(
        category: 'build',
        summary:
            'Error with api_key=sk-123456789012345678901234 in /home/user/app',
        evidence: ['Bearer secretToken123456789'],
      );

      final response = await service.analyze(request);

      expect(response, isNotNull);
      expect(response!.isAdvisory, isTrue);
      expect(capturedRequest.summary, contains('api_key=[REDACTED]'));
      expect(capturedRequest.summary, contains('~/app'));
      expect(capturedRequest.evidence.first, contains('Bearer [REDACTED]'));
    });
  });
}

class _CapturingAiProvider implements AiProvider {
  _CapturingAiProvider(this.onCapture);

  final void Function(AiRequest request) onCapture;

  @override
  Future<AiResponse> analyze(AiRequest request) async {
    onCapture(request);
    return const AiResponse(
      summary: 'Captured advisory summary',
      probableCauses: ['Cause 1'],
      suggestions: ['Suggestion 1'],
      confidence: 0.85,
    );
  }
}
