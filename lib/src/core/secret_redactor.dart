/// Redacts credential-like values before they are included in reports.
class SecretRedactor {
  const SecretRedactor._();

  static String redact(String input) {
    if (input.isEmpty) {
      return input;
    }

    var redacted = input;
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'((?:api[_-]?key|token|secret|password|pass|authorization)\s*[:=]\s*(?:bearer\s+)?)\S+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );

    redacted = redacted.replaceAllMapped(
      RegExp(r'((?:authorization)\s*:\s*bearer\s+)\S+', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );

    redacted = redacted.replaceAllMapped(
      RegExp(r'((?:bearer)\s+)\S+', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );

    return redacted;
  }
}
