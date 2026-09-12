/// Helper class for normalizing raw build logs before pattern analysis.
class NormalizedLogResult {
  const NormalizedLogResult({
    required this.rawLog,
    required this.cleanLog,
    required this.lines,
    required this.hasAnsi,
    required this.hasCiHeader,
    required this.hasGradlePrefix,
    required this.hasXcodePrefix,
  });

  final String rawLog;
  final String cleanLog;
  final List<String> lines;
  final bool hasAnsi;
  final bool hasCiHeader;
  final bool hasGradlePrefix;
  final bool hasXcodePrefix;
}

/// Utility for normalizing build log formatting, ANSI colors, line endings, and log runner headers.
class BuildLogNormalizer {
  const BuildLogNormalizer._();

  static final _ansiRegExp = RegExp(r'\x1B\[[0-9;]*[mGK]|\033\[[0-9;]*[mGK]');
  static final _lineEndingRegExp = RegExp(r'\r\n?');
  static final _ciTimestampRegExp = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d+Z\s+',
  );
  static final _multipleBlankLinesRegExp = RegExp(r'\n{3,}');

  static NormalizedLogResult normalize(
    String rawLog, {
    int maxLogSizeBytes = 10485760, // 10MB default limit
  }) {
    var text = rawLog;

    // Truncate oversized logs to head + tail if exceeding maxLogSizeBytes
    if (maxLogSizeBytes > 0 && text.length > maxLogSizeBytes) {
      final sliceChunkSize = maxLogSizeBytes ~/ 4;
      final head = text.substring(0, sliceChunkSize);
      final tail = text.substring(text.length - sliceChunkSize);
      text =
          '$head\n\n[... LOG TRUNCATED DUE TO SIZE LIMIT: ${rawLog.length} bytes ...]\n\n$tail';
    }

    final hasAnsi = _ansiRegExp.hasMatch(text);
    if (hasAnsi) {
      text = text.replaceAll(_ansiRegExp, '');
    }

    // Line ending normalization
    text = text.replaceAll(_lineEndingRegExp, '\n');

    final lines = text.split('\n');
    final cleanLines = <String>[];
    var hasCiHeader = false;
    var hasGradlePrefix = false;
    var hasXcodePrefix = false;

    for (var line in lines) {
      // Detect and strip CI timestamps or runner prefixes
      if (_ciTimestampRegExp.hasMatch(line) ||
          line.startsWith('##[error]') ||
          line.startsWith('[ci]')) {
        hasCiHeader = true;
        line = line
            .replaceAll(_ciTimestampRegExp, '')
            .replaceAll('##[error]', '')
            .replaceAll('[ci]', '')
            .trim();
      }

      // Detect Gradle prefixes
      if (line.startsWith('> Task :') ||
          line.startsWith('FAILURE:') ||
          line.startsWith('* What went wrong:')) {
        hasGradlePrefix = true;
      }

      // Detect Xcode prefixes
      if (line.startsWith('▸') || line.contains('xcodebuild[')) {
        hasXcodePrefix = true;
      }

      cleanLines.add(line);
    }

    // Collapse multiple blank lines
    var cleanText = cleanLines.join('\n');
    cleanText = cleanText.replaceAll(_multipleBlankLinesRegExp, '\n\n').trim();

    return NormalizedLogResult(
      rawLog: rawLog,
      cleanLog: cleanText,
      lines: cleanLines,
      hasAnsi: hasAnsi,
      hasCiHeader: hasCiHeader,
      hasGradlePrefix: hasGradlePrefix,
      hasXcodePrefix: hasXcodePrefix,
    );
  }
}
