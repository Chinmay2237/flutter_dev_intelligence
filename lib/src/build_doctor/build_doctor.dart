import '../core/models.dart';
import 'build_doctor_engine.dart';

export 'build_doctor_engine.dart';
export 'input_loader.dart';
export 'log_normalizer.dart';
export 'log_parser.dart';
export 'diagnostic_rules.dart';
export 'rule_matcher.dart';
export 'root_cause_classifier.dart';
export 'reporting.dart';

/// Entry point facade for Build Doctor diagnostics.
class BuildDoctor {
  const BuildDoctor();

  /// Analyzes raw build log string and returns a DiagnosticReport.
  static Future<DiagnosticReport> analyzeLog(
    String logContent, {
    String sourceLabel = 'build.log',
    String projectName = 'flutter-project',
  }) async {
    return BuildDoctorEngine.analyze(
      options: BuildDoctorEngineOptions(
        logContent: logContent,
        logPath: sourceLabel,
        projectName: projectName,
      ),
    );
  }

  /// Parses a raw build log and returns a top-priority diagnostic finding.
  static Future<DiagnosticFinding?> detectIssueFromLog(String log) async {
    final report = await analyzeLog(log);
    if (report.primaryFindings.isNotEmpty) {
      return report.primaryFindings.first;
    }
    if (report.findings.isNotEmpty) {
      return report.findings.first;
    }
    return null;
  }
}
