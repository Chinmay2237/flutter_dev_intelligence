import '../core/models.dart';
import 'build_doctor_rule.dart';

/// Parses build log text into a set of evidence-based issues using the BuildDoctorRuleRegistry.
class BuildLogParser {
  const BuildLogParser({this.registry = const BuildDoctorRuleRegistry()});

  final BuildDoctorRuleRegistry registry;

  static List<DiagnosticIssue> parse(
    String log, {
    BuildDoctorRuleRegistry registry = const BuildDoctorRuleRegistry(),
  }) {
    if (log.trim().isEmpty) {
      return const <DiagnosticIssue>[];
    }

    final cleanLog = _normalizeLog(log);
    return registry.analyze(cleanLog);
  }

  static String _normalizeLog(String log) {
    var normalized = log.replaceAll(RegExp(r'\u001b\[[0-9;]*m'), '');
    normalized = normalized.replaceAll(RegExp(r'\r\n?'), '\n');
    return normalized.trim();
  }
}
