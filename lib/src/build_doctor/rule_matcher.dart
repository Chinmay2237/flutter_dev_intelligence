import '../core/models.dart';
import 'diagnostic_rules.dart';
import 'log_normalizer.dart';
import 'log_parser.dart';

class RuleMatcher {
  static List<DiagnosticFinding> matchRules(
    NormalizedLog normalizedLog,
    ParsedLogOutput parsedOutput, {
    List<DiagnosticRule>? rules,
  }) {
    final activeRules = rules ?? DiagnosticRuleCatalog.allRules;
    final findings = <DiagnosticFinding>[];

    for (final rule in activeRules) {
      try {
        final finding = rule.match(normalizedLog, parsedOutput);
        if (finding != null) {
          findings.add(finding);
        }
      } catch (e) {
        // Continue processing rules even if an individual rule evaluation fails
      }
    }

    return findings;
  }
}
