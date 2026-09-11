import '../core/models.dart';

/// UI quality inspector for viewport and accessibility heuristics.
class UiDoctor {
  const UiDoctor();

  static DiagnosticReport inspectViewport({
    required num width,
    required num height,
    required num contentWidth,
    required num contentHeight,
  }) {
    final issues = <DiagnosticIssue>[];

    if (contentWidth > width) {
      issues.add(
        DiagnosticIssue(
          id: 'viewport_overflow',
          category: DiagnosticCategory.layout,
          severity: DiagnosticSeverity.medium,
          title: 'Viewport overflow risk detected',
          description:
              'The content width exceeds the available viewport width, which may cause horizontal overflow.',
          evidence: [
            EvidenceReference(
              type: EvidenceType.configuration,
              label: 'viewport',
              value:
                  'viewport=${width}x$height, content=${contentWidth}x$contentHeight',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action: 'Wrap content with responsive layout constraints',
              details:
                  'Use Flexible, Expanded, or MediaQuery-aware layouts to prevent overflow on narrow screens.',
            ),
          ],
          confidence: 0.8,
        ),
      );
    }

    if (issues.isEmpty) {
      return DiagnosticReport(
        id: 'ui_ok',
        createdAt: DateTime.now(),
        projectName: 'viewport-check',
        issues: const <DiagnosticIssue>[],
      );
    }

    return DiagnosticReport(
      id: 'ui_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: 'viewport-check',
      issues: issues,
      metrics: <String, dynamic>{
        'viewport_width': width,
        'viewport_height': height,
        'content_width': contentWidth,
        'content_height': contentHeight,
      },
    );
  }
}
