import 'dart:convert';
import '../../core/models.dart';

class JsonReporter {
  const JsonReporter._();

  static String render(DiagnosticReport report) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(report.toJson());
  }
}
