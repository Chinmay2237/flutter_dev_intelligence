import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

/// Detailed information about a Dart syntax or parsing error.
class ParseErrorDetail {
  const ParseErrorDetail({
    required this.message,
    required this.offset,
    required this.length,
    this.line,
    this.column,
    this.errorCode,
  });

  final String message;
  final int offset;
  final int length;
  final int? line;
  final int? column;
  final String? errorCode;

  @override
  String toString() => '$message at offset $offset (line ${line ?? '?'})';

  Map<String, dynamic> toJson() => {
    'message': message,
    'offset': offset,
    'length': length,
    if (line != null) 'line': line,
    if (column != null) 'column': column,
    if (errorCode != null) 'errorCode': errorCode,
  };
}

/// Result of parsing a single Dart source file or memory buffer into an AST.
class ParseResult {
  const ParseResult({
    required this.filePath,
    required this.unit,
    required this.lineInfo,
    required this.parseErrors,
    required this.hasFatalError,
    required this.byteLength,
  });

  final String filePath;
  final CompilationUnit? unit;
  final LineInfo? lineInfo;
  final List<ParseErrorDetail> parseErrors;
  final bool hasFatalError;
  final int byteLength;

  bool get isValid => unit != null && !hasFatalError;
}

/// Robust Dart AST parser resilient against syntax errors, partial files, and unexpected parse exceptions.
class AstParser {
  const AstParser();

  /// Safely parses [content] into a [ParseResult].
  static ParseResult parse(String content, {String filePath = '<memory>'}) {
    final byteLength = content.length;
    if (content.trim().isEmpty) {
      return ParseResult(
        filePath: filePath,
        unit: null,
        lineInfo: LineInfo([0]),
        parseErrors: const <ParseErrorDetail>[],
        hasFatalError: false,
        byteLength: byteLength,
      );
    }

    try {
      final parsed = parseString(
        content: content,
        path: filePath,
        throwIfDiagnostics: false,
      );

      final errors = <ParseErrorDetail>[];
      for (final error in parsed.errors) {
        final loc = parsed.lineInfo.getLocation(error.offset);
        errors.add(
          ParseErrorDetail(
            message: error.message,
            offset: error.offset,
            length: error.length,
            line: loc.lineNumber,
            column: loc.columnNumber,
            // ignore: deprecated_member_use
            errorCode: error.errorCode.name,
          ),
        );
      }

      return ParseResult(
        filePath: filePath,
        unit: parsed.unit,
        lineInfo: parsed.lineInfo,
        parseErrors: errors,
        hasFatalError: false,
        byteLength: byteLength,
      );
    } catch (e) {
      return ParseResult(
        filePath: filePath,
        unit: null,
        lineInfo: null,
        parseErrors: [
          ParseErrorDetail(
            message: 'Unhandled parser exception: $e',
            offset: 0,
            length: 0,
          ),
        ],
        hasFatalError: true,
        byteLength: byteLength,
      );
    }
  }
}
