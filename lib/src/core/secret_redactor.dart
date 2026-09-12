/// Redacts credential-like values, private URLs, cloud keys, tokens, and sensitive paths before reporting or AI transmission.
class SecretRedactor {
  const SecretRedactor._();

  static String redact(String input) {
    if (input.isEmpty) {
      return input;
    }

    var redacted = input;

    // 1. Redact Private SSH & RSA Keys (multiline / dotAll matching)
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'-----BEGIN\s+(?:RSA\s+|OPENSSH\s+|EC\s+|DSA\s+)?PRIVATE\s+KEY-----[\s\S]*?-----END\s+(?:RSA\s+|OPENSSH\s+|EC\s+|DSA\s+)?PRIVATE\s+KEY-----',
        caseSensitive: false,
        multiLine: true,
        dotAll: true,
      ),
      (match) => '[REDACTED_PRIVATE_KEY]',
    );

    // 2. Redact JWT tokens (eyJ...)
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
      ),
      (match) => '[REDACTED_JWT_TOKEN]',
    );

    // 3. Redact Specific Cloud & Developer Provider Tokens (GitHub, GitLab, AWS, GCP, OpenAI)
    redacted = redacted.replaceAll(
      RegExp(r'ghp_[A-Za-z0-9_-]{20,50}'),
      '[REDACTED_GITHUB_TOKEN]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'github_pat_[A-Za-z0-9_]{50,100}'),
      '[REDACTED_GITHUB_TOKEN]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'glpat-[A-Za-z0-9_-]{15,40}'),
      '[REDACTED_GITLAB_TOKEN]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'AKIA[0-9A-Z]{16}'),
      '[REDACTED_AWS_KEY]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'AIzaSy[A-Za-z0-9_-]{20,50}'),
      '[REDACTED_GCP_KEY]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'sk-[A-Za-z0-9_-]{15,}'),
      '[REDACTED_OPENAI_KEY]',
    );

    // 4. Redact Bearer headers & tokens
    redacted = redacted.replaceAllMapped(
      RegExp(r'((?:authorization)\s*:\s*bearer\s+)\S+', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );
    redacted = redacted.replaceAllMapped(
      RegExp(r'\b(bearer\s+)[A-Za-z0-9_.-]{10,}\b', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );

    // 5. Redact Key-Value Secret assignments (tokens, secrets, API keys, passwords, keystores)
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'((?:api[_-]?key|token|secret|password|passwd|pass|authorization|access[_-]?token|storePassword|keyPassword|firebase[_-]?token|CI_JOB_TOKEN|GITHUB_TOKEN)\s*[:=]\s*(?:bearer\s+)?)(?!\[REDACTED)[^\s;,]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );

    // 6. Redact Private URLs with embedded credentials (e.g. https://user:pass@example.com)
    redacted = redacted.replaceAllMapped(
      RegExp(r'https?://[^:\s/]+:[^@\s/]+@', caseSensitive: false),
      (match) => 'https://[REDACTED]@',
    );

    // 7. Normalize user home directory paths (/home/username or /Users/username)
    redacted = redacted.replaceAllMapped(
      RegExp(r'/(?:home|Users)/[A-Za-z0-9_.-]+'),
      (match) => '~',
    );

    return redacted;
  }
}

/// Alias for SecretRedactor for privacy domain semantics.
typedef PrivacyRedactor = SecretRedactor;
