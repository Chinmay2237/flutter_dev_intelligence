# Configuration Reference (`flutter_dev_intelligence.yaml`)

Projects can configure diagnostic rule behavior, path exclusions, scale limits, severity thresholds, performance parameters, and suppression rules via `flutter_dev_intelligence.yaml`.

---

## File Location & Precedence

The engine automatically searches for configuration files in the following order:
1. File path specified via `--config=<path>` argument.
2. `flutter_dev_intelligence.yaml` in the project root directory.
3. `.flutter_dev_intelligence.yaml` in the project root directory.
4. Built-in defaults (if no configuration file exists).

---

## Example Schema (Version 1)

```yaml
version: 1

analysis:
  severity_threshold: info        # info | low | medium | high | critical
  confidence_threshold: 0.0       # 0.0 to 1.0
  enable_ui_doctor: true
  enable_build_doctor: true
  enable_performance: true

paths:
  exclude:
    - 'build/**'
    - '.dart_tool/**'
    - '**/generated/**'
    - '**/*.g.dart'
    - '**/*.freezed.dart'
  include: []
  exclude_tests: false
  exclude_examples: false
  exclude_generated: true

limits:
  max_file_size_bytes: 2097152    # 2MB limit per Dart file
  max_log_size_bytes: 10485760    # 10MB head/tail log truncation limit
  max_trace_events: 50000         # 50,000 DevTools trace event cap
  max_issues_count: 500           # Maximum issues returned in report

rules:
  disabled:
    - 'ui.oversized-dimension'
  enabled: []                     # If non-empty, only these rule IDs will run

performance:
  refresh_rate_hz: 60.0          # Hardware target refresh rate in Hz
  frame_budget_ms: 16.67         # Auto-calculated frame budget in ms

ai:
  enabled: false                 # AI explanations are disabled by default
  provider: 'mock'               # Provider selection

privacy:
  redact_secrets: true           # Redact tokens, passwords, keys, and paths

output:
  format: 'terminal'             # terminal | json | markdown
  color: 'auto'                  # auto | always | never
  quiet: false
  verbose: false

suppressions:
  - rule: 'ui.nested-scrollable'
    file: 'lib/screens/feed_screen.dart'
    line: 45
    reason: 'Verified carousel layout mitigation'
    owner: 'ui-team'
    expiration_date: '2026-12-31'
```

---

## Suppression Rules

Suppression rules allow teams to suppress specific diagnostic findings.

- **`rule`**: Rule ID (or `*` to match all rules).
- **`file`**: Relative glob pattern matching file paths.
- **`line`**: Optional 1-based line number.
- **`reason`**: Explanation for audit purposes.
- **`expiration_date`**: Optional ISO-8601 expiration timestamp after which suppression automatically deactivates.
