import 'dart:io';

class LogInputResult {
  final String content;
  final String sourceLabel;
  final bool isTruncated;
  final int originalSizeBytes;

  const LogInputResult({
    required this.content,
    required this.sourceLabel,
    this.isTruncated = false,
    this.originalSizeBytes = 0,
  });
}

class InputLoader {
  const InputLoader._();

  static Future<LogInputResult> fromFile(
    String filePath, {
    int maxSizeBytes = 10485760, // 10MB default limit
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Log file not found', filePath);
    }

    final stat = await file.stat();
    final originalSize = stat.size;

    if (originalSize == 0) {
      return LogInputResult(
        content: '',
        sourceLabel: filePath,
        isTruncated: false,
        originalSizeBytes: 0,
      );
    }

    if (originalSize > maxSizeBytes) {
      // Read last maxSizeBytes bytes to retain tail of long build logs
      final randomAccess = await file.open(mode: FileMode.read);
      try {
        await randomAccess.setPosition(originalSize - maxSizeBytes);
        final bytes = await randomAccess.read(maxSizeBytes);
        final text = systemEncoding.decode(bytes);
        return LogInputResult(
          content: text,
          sourceLabel: filePath,
          isTruncated: true,
          originalSizeBytes: originalSize,
        );
      } finally {
        await randomAccess.close();
      }
    }

    final text = await file.readAsString();
    return LogInputResult(
      content: text,
      sourceLabel: filePath,
      isTruncated: false,
      originalSizeBytes: originalSize,
    );
  }

  static LogInputResult fromString(
    String logText, {
    String sourceLabel = 'stdin',
    int maxSizeBytes = 10485760,
  }) {
    final bytesLength = logText.length;
    if (bytesLength > maxSizeBytes) {
      final truncatedText = logText.substring(logText.length - maxSizeBytes);
      return LogInputResult(
        content: truncatedText,
        sourceLabel: sourceLabel,
        isTruncated: true,
        originalSizeBytes: bytesLength,
      );
    }
    return LogInputResult(
      content: logText,
      sourceLabel: sourceLabel,
      isTruncated: false,
      originalSizeBytes: bytesLength,
    );
  }
}
