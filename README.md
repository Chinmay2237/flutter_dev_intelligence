# Flutter Dev Intelligence (`flutter_dev_intelligence`)

[![Pub Version](https://img.shields.io/pub/v/flutter_dev_intelligence.svg)](https://pub.dev/packages/flutter_dev_intelligence)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**`flutter_dev_intelligence`** is a deterministic, offline-first developer diagnostics toolkit for Flutter and Dart applications. It brings evidence-based static AST UI quality analysis, multi-platform build log troubleshooting (Android, iOS, Gradle, Xcode, Dart, CI), and DevTools runtime performance investigation into a single, unified developer CLI and Dart API.

---

## What the Package Does

- **Project & Build Diagnostics (`doctor`)**: Scans Flutter packages, `pubspec.yaml`, `pubspec.lock` lockfile consistency, and matches build logs against 40 deterministic root-cause rules across Android, iOS, Gradle, Xcode, and dependency resolution.
- **Static AST UI Analysis (`ui-doctor`)**: Analyzes Dart widget AST structures to detect layout anti-patterns (nested scrollables, shrink-wrap misuse, unconstrained scrollables, Expanded/Positioned misuse, oversized dimensions, setState misuse, expensive build operations, controller disposal, and accessibility issues).
- **Build Log Troubleshooting (`build-doctor`)**: Normalizes ANSI, line endings, and CI runner headers, then classifies build outcomes and maps exact log line evidence to root-cause fixes.
- **Performance Investigation (`perf-investigator`)**: Parses DevTools Chrome traces, frame timings arrays, and summarized metrics to compute p50..p99 percentiles, mean, min, max, slow frame percentages, and hardware refresh rate budget suggestions.
- **Privacy-First & Secret Redaction**: Operates 100% offline with zero network calls by default. Includes automated secret redaction for API keys (OpenAI, AWS, GCP), Bearer tokens, credentials, and user home file paths.

---

## Who It Is For

- **Flutter Developers**: Get fast, actionable feedback on layout bugs, missing controllers disposal, and build failures directly in your terminal or IDE.
- **Tech Leads & Monorepo Maintainers**: Enforce architectural guidelines, file size safeguards, and diagnostic rule standards across large Flutter repositories.
- **CI / CD Pipelines**: Run deterministic diagnostic checks on pull requests with structured exit codes (`0` clean, `1` issues found) and machine-readable JSON/Markdown outputs.

---

## What It Does NOT Do

To maintain technical accuracy, `flutter_dev_intelligence` explicitly does **not**:
- Replace Flutter DevTools or real-device profiling (it analyzes traces and static AST; it does not execute live UI layout math at runtime).
- Guarantee zero false positives (static analysis relies on AST heuristics and confidence scoring).
- Automatically mutate or re-write user widget code without explicit preview and user confirmation.
- Upload source files or build logs to external servers (all analysis runs locally).

---

## Installation

### Activate as a Global CLI Tool

```bash
dart pub global activate flutter_dev_intelligence
```

### Add to a Flutter / Dart Package

```yaml
dev_dependencies:
  flutter_dev_intelligence: ^1.0.0
```

---

## Supported CLI Commands

| Command | Aliases | Description |
| :--- | :--- | :--- |
| `flutter-dev doctor` | `doc` | Runs complete project health, pubspec, lockfile, UI AST, and build log diagnostics. |
| `flutter-dev ui-doctor` | `ui` | Performs static AST analysis on Flutter Dart source files below `lib/`. |
| `flutter-dev build-doctor` | `build` | Analyzes Android, iOS, Gradle, Xcode, or CI build log files. |
| `flutter-dev perf-investigator` | `perf` | Analyzes DevTools Chrome traces (`traceEvents`) or frame duration arrays. |

---

## Example Usage & Output

### 1. Terminal Output (`--format=terminal`)

```text
Flutter Dev Intelligence 1.0.0
────────────────────────────────────────────
Command: ui-doctor
Project: example/
Duration: 184 ms
Files analyzed: 42
Rules executed: 17

Summary
────────────────────────────────────────────
Critical: 0  |  High: 1  |  Medium: 2  |  Low: 3  |  Info: 4

Issues
────────────────────────────────────────────
[HIGH] ui.nested-scrollable
  File: lib/src/screens/feed_screen.dart:45
  Title: Unmitigated same-axis nested scrollable widget
  Evidence: ListView(...) nested inside SingleChildScrollView(...)
  Suggestion: Add physics: NeverScrollableScrollPhysics() or shrinkWrap: true.
```

### 2. JSON Output (`--format=json`)

```json
{
  "schemaVersion": "1.0",
  "tool": {
    "name": "flutter_dev_intelligence",
    "version": "1.0.0"
  },
  "analysis": {
    "engine": "ui-doctor",
    "status": "completed",
    "durationMs": 184,
    "filesAnalyzed": 42
  },
  "summary": {
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 3,
    "info": 4
  },
  "issues": [
    {
      "id": "ui.nested-scrollable",
      "category": "layout",
      "severity": "high",
      "title": "Unmitigated same-axis nested scrollable widget",
      "filePath": "lib/src/screens/feed_screen.dart",
      "line": 45,
      "confidence": 0.95
    }
  ]
}
```

### 3. Markdown Output (`--format=markdown`)

```markdown
# Flutter Dev Intelligence Report

- **Tool:** flutter_dev_intelligence 1.0.0
- **Engine:** ui-doctor
- **Files Analyzed:** 42

## Summary
- **High:** 1
- **Medium:** 2
- **Low:** 3

## Diagnostic Issues
### [HIGH] Unmitigated same-axis nested scrollable widget (`ui.nested-scrollable`)
- **Location:** `lib/src/screens/feed_screen.dart:45`
- **Suggestion:** Add `NeverScrollableScrollPhysics` to inner scrollable.
```

---

## Project Configuration (`flutter_dev_intelligence.yaml`)

Place `flutter_dev_intelligence.yaml` in your project root:

```yaml
version: 1

analysis:
  severity_threshold: low
  confidence_threshold: 0.75
  enable_ui_doctor: true
  enable_build_doctor: true
  enable_performance: true

paths:
  exclude:
    - 'build/**'
    - '.dart_tool/**'
    - '**/*.g.dart'
  exclude_tests: false
  exclude_examples: false

limits:
  max_file_size_bytes: 2097152    # Skip files > 2MB
  max_log_size_bytes: 10485760    # 10MB head/tail log truncation
  max_trace_events: 50000         # 50,000 trace events limit
  max_issues_count: 500           # Cap report issue list

rules:
  disabled:
    - 'ui.oversized-dimension'

suppressions:
  - rule: 'ui.nested-scrollable'
    file: 'lib/src/legacy/*.dart'
    reason: 'Legacy carousel scrollable structure maintained for backwards compatibility.'
```

---

## CI / CD Integration

Use standard shell exit codes (`0` clean, `1` issues/error) in CI pipelines:

### GitHub Actions

```yaml
- name: Run Flutter Dev Intelligence UI Check
  run: |
    dart pub global activate flutter_dev_intelligence
    flutter-dev ui-doctor --project=. --format=terminal --severity=high
```

---

## Privacy, AI & Security Defaults

- **Zero Network by Default**: 100% of diagnostic analyses run locally on your workspace.
- **AI Integration (Opt-In Advisory)**: Optional AI explanations require explicit user opt-in (`--ai` or `ai.enabled: true`). If enabled, inputs pass through `PrivacyRedactor` to mask keys and paths before transmission.
- **Secret Redaction**: Automatically redacts Bearer tokens, OpenAI keys (`sk-...`), AWS keys, GCP keys, passwords, and user home directory paths (`/home/user/` -> `~/`).

---

## Resource Links

- [Rule Catalog](docs/rules/README.md)
- [CLI Reference Guide](docs/cli.md)
- [Configuration Reference](docs/configuration.md)
- [Privacy & Security Policy](docs/privacy_and_security.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Security Guidelines](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [License (MIT)](LICENSE)
