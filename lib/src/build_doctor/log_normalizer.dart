import '../core/secret_redactor.dart';

class NormalizedLog {
  final String rawContent;
  final String normalizedContent;
  final List<String> lines;
  final bool containsAnsi;
  final bool redactSecrets;

  const NormalizedLog({
    required this.rawContent,
    required this.normalizedContent,
    required this.lines,
    required this.containsAnsi,
    required this.redactSecrets,
  });
}

class LogNormalizer {
  static final RegExp _ansiRegex = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');

  static String stripAnsi(String text) {
    return text.replaceAll(_ansiRegex, '');
  }

  static NormalizedLog normalize(String rawLog, {bool redactSecrets = true}) {
    final containsAnsi = _ansiRegex.hasMatch(rawLog);

    // 1. Strip ANSI codes
    var text = containsAnsi ? stripAnsi(rawLog) : rawLog;

    // 2. Normalize line endings (\r\n and \r to \n)
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 3. Strip non-printable control characters except tab and newline
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 4. Redact secrets if requested
    if (redactSecrets) {
      text = SecretRedactor.redact(text);
    }

    final lines = text.split('\n');

    return NormalizedLog(
      rawContent: rawLog,
      normalizedContent: text,
      lines: lines,
      containsAnsi: containsAnsi,
      redactSecrets: redactSecrets,
    );
  }
}
