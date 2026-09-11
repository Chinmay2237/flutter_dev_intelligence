/// Redacts credential-like values, private URLs, cloud keys, and sensitive user paths before reporting or AI transmission.
class SecretRedactor {
  const SecretRedactor._();

  static String redact(String input) {
    if (input.isEmpty) {
      return input;
    }

    var redacted = input;

    // 1. Redact key-value pairs for tokens, secrets, API keys, and passwords
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'((?:api[_-]?key|token|secret|password|pass|authorization|access[_-]?token)\s*[:=]\s*(?:bearer\s+)?)\S+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );

    // 2. Redact Bearer headers
    redacted = redacted.replaceAllMapped(
      RegExp(r'((?:authorization)\s*:\s*bearer\s+)\S+', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );
    redacted = redacted.replaceAllMapped(
      RegExp(r'((?:bearer)\s+)[A-Za-z0-9_.-]{10,}', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );

    // 3. Redact private URLs with embedded credentials (e.g., https://user:pass@example.com)
    redacted = redacted.replaceAllMapped(
      RegExp(r'https?://[^:\s/]+:[^@\s/]+@', caseSensitive: false),
      (match) => 'https://[REDACTED]@',
    );

    // 4. Redact AWS access key IDs and OpenAI / GCP key patterns
    redacted = redacted.replaceAll(
      RegExp(r'AKIA[0-9A-Z]{16}'),
      '[REDACTED_AWS_KEY]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'AIzaSy[A-Za-z0-9_-]{30,35}'),
      '[REDACTED_GCP_KEY]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'sk-[A-Za-z0-9_-]{20,}'),
      '[REDACTED_OPENAI_KEY]',
    );

    // 5. Normalize user home directory paths (/home/username or /Users/username)
    redacted = redacted.replaceAllMapped(
      RegExp(r'/(?:home|Users)/[A-Za-z0-9_.-]+'),
      (match) => '~',
    );

    return redacted;
  }
}

/// Alias for SecretRedactor for privacy domain semantics.
typedef PrivacyRedactor = SecretRedactor;
