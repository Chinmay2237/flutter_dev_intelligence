import 'log_normalizer.dart';

class LogEvent {
  final String rawText;
  final int startLineNumber;
  final int endLineNumber;
  final String? taskName;
  final String? sourceFilePath;
  final int? sourceLineNumber;
  final List<String> contextLines;

  const LogEvent({
    required this.rawText,
    required this.startLineNumber,
    required this.endLineNumber,
    this.taskName,
    this.sourceFilePath,
    this.sourceLineNumber,
    this.contextLines = const [],
  });
}

class ParsedLogOutput {
  final NormalizedLog normalizedLog;
  final List<LogEvent> events;
  final List<String> taskNames;
  final List<String> unrecognizedLines;

  const ParsedLogOutput({
    required this.normalizedLog,
    required this.events,
    required this.taskNames,
    required this.unrecognizedLines,
  });
}

class LogParser {
  static final RegExp _taskHeaderRegex = RegExp(
    r'^(?:Task\s+|:)([a-zA-Z0-9_:-]+)\s+(FAILED|SUCCESS|SKIPPED|EXECUTED)',
    caseSensitive: false,
  );

  static final RegExp _dartCompilerErrorRegex = RegExp(
    r'^([a-zA-Z0-9_\-/\\]+\.dart):(\d+):(\d+):\s+(Error|Warning|Info):\s+(.+)$',
    multiLine: true,
  );

  static ParsedLogOutput parse(NormalizedLog normalizedLog) {
    final lines = normalizedLog.lines;
    final events = <LogEvent>[];
    final taskNames = <String>[];
    final matchedLineIndexes = <int>{};

    // 1. Extract Gradle / Flutter build task headers
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final taskMatch = _taskHeaderRegex.firstMatch(line);
      if (taskMatch != null) {
        final taskName = taskMatch.group(1)!;
        taskNames.add(taskName);
        matchedLineIndexes.add(i);

        final contextStart = (i - 3 < 0) ? 0 : i - 3;
        final contextEnd = (i + 3 >= lines.length) ? lines.length - 1 : i + 3;
        final context = lines.sublist(contextStart, contextEnd + 1);

        events.add(
          LogEvent(
            rawText: line,
            startLineNumber: i + 1,
            endLineNumber: i + 1,
            taskName: taskName,
            contextLines: context,
          ),
        );
      }
    }

    // 2. Extract Dart compiler error line blocks
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final compilerMatch = _dartCompilerErrorRegex.firstMatch(line);
      if (compilerMatch != null) {
        final filePath = compilerMatch.group(1);
        final lineNum = int.tryParse(compilerMatch.group(2) ?? '');
        matchedLineIndexes.add(i);

        // Capture snippet lines following compiler error
        var endIdx = i;
        final snippetLines = <String>[line];
        while (endIdx + 1 < lines.length &&
            (lines[endIdx + 1].startsWith(' ') ||
                lines[endIdx + 1].startsWith('\t') ||
                lines[endIdx + 1].contains('^'))) {
          endIdx++;
          snippetLines.add(lines[endIdx]);
          matchedLineIndexes.add(endIdx);
        }

        events.add(
          LogEvent(
            rawText: snippetLines.join('\n'),
            startLineNumber: i + 1,
            endLineNumber: endIdx + 1,
            sourceFilePath: filePath,
            sourceLineNumber: lineNum,
            contextLines: snippetLines,
          ),
        );
      }
    }

    // 3. Identify unrecognized/unmatched log lines (excluding blank lines)
    final unrecognized = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isNotEmpty && !matchedLineIndexes.contains(i)) {
        unrecognized.add(lines[i]);
      }
    }

    return ParsedLogOutput(
      normalizedLog: normalizedLog,
      events: events,
      taskNames: taskNames,
      unrecognizedLines: unrecognized,
    );
  }
}
