# Flutter Dev Intelligence

[![pub package](https://img.shields.io/pub/v/flutter_dev_intelligence.svg)](https://pub.dev/packages/flutter_dev_intelligence)
[![Dart SDK](https://img.shields.io/badge/dart-%3E%3D3.11.5-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D1.17.0-blue.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

An evidence-based developer diagnostics toolkit for Flutter applications. Inspect build logs, Dart AST static UI layout patterns, dependency lockfiles, and performance frame traces with structured, machine-readable diagnostics.

---

## Capabilities

- 🔍 **Project & Lockfile Diagnostics (`doctor`):** Validates package structure, dependency kinds (`direct main`, `direct dev`, `transitive`), and lockfile consistency while properly excluding SDK range constraints (`environment.sdk`, `environment.flutter`).
- 🎨 **Dart AST Static UI Analysis (`ui-doctor`):** Heuristic static analysis for Flutter UI code:
  - Suspicious `setState()` calls directly in build methods (with boundary detection for callbacks like `onTap` / `onPressed`).
  - Contextual nested scrollables (distinguishing valid horizontal carousels as `INFO` vs unconstrained or same-direction scrolling conflicts).
  - Unconstrained scrollables in Flex containers (`Column` / `Row`).
  - Misused `Expanded` / `Flexible` widgets outside Flex parents and oversized literal pixel dimensions.
- 🛠️ **Build Log Engine (`build-doctor`):** Deterministic parser for Android (Gradle, Kotlin, Manifest, NDK) and iOS (Xcode, CocoaPods, Swift, code signing) build logs. Unmatched logs are reported as informational results rather than false defects.
- ⚡ **Performance Trace Investigator (`performance`):** Frame timing analysis (p50, p90, p99, build vs raster bottleneck detection) supporting DevTools timeline JSON trace exports, raw frame lists, and pre-summarized metrics.
- 💻 **Production Developer CLI:** Semantic ANSI terminal colors (`--color auto|always|never`), TTY auto-detection, `--stdin` pipe support for log and trace commands, `--format terminal|json|markdown`, and saved report export (`--output`).
- 🛡️ **Read-Only & Privacy First:** Diagnostic commands are strictly read-only. Includes `SecretRedactor` for sanitizing logs before external sharing. No external network requests occur without explicit configuration.

---

## Scope & Limitations

> [!NOTE]
> **Heuristic Diagnostics:** `flutter_dev_intelligence` performs static source analysis and log pattern matching. It does not execute your application runtime or profile live device layouts.

- **Static UI Analysis:** Findings are derived from Dart AST analysis. Runtime layout, gesture physics, and frame rendering require execution in a Flutter host app.
- **Build Log Analysis:** Analysis is limited to implemented deterministic rules. Unmatched log outputs are reported as `INFO` ("No known build issue detected") with exit code `0`.
- **Performance Analysis:** Requires supplying compatible trace JSON data exported from DevTools or custom timing logs.

---

## Installation

Add `flutter_dev_intelligence` to your package's `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_dev_intelligence: ^0.1.0-dev.2
```

Fetch dependencies:

```bash
flutter pub get
```

---

## CLI Usage

Run project-wide diagnostics from any Flutter or Dart project root:

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project .
```

### Command Reference

| Command | Required Input | Example | Description |
|---|---|---|---|
| `doctor` | Directory (`--project`) | `flutter-dev doctor --project .` | Complete project diagnosis (`pubspec`, lockfile, static UI, logs) |
| `build-doctor` | File (`--log`) or Stdin (`--stdin`) | `flutter-dev build-doctor --log build.log` | Analyze Flutter/Dart build logs |
| `ui-doctor` | Directory (`--project`) | `flutter-dev ui-doctor --project .` | Static Dart AST UI quality heuristics |
| `performance` | JSON (`--input`) or Stdin (`--stdin`) | `flutter-dev performance --input trace.json` | Analyze DevTools or frame timing trace JSON |

---

## Piping and Stdin Integration

`flutter_dev_intelligence` supports standard input (`--stdin`) for `build-doctor` and `performance`:

### 1. Pipe build logs into `build-doctor`:

```bash
flutter build apk 2>&1 | dart run flutter_dev_intelligence:flutter_dev build-doctor --stdin
```

### 2. Pipe performance trace JSON into `performance`:

```bash
cat trace.json | dart run flutter_dev_intelligence:flutter_dev performance --stdin
```

*Note: `doctor` and `ui-doctor` inspect the project workspace on disk (`--project <path>`) and do not accept `--stdin`.*

---

## Performance Trace Formats

The `performance` command accepts three supported JSON input formats:

1. **DevTools Timeline Export JSON** (`{ "traceEvents": [...] }`): Exported from Flutter DevTools Performance tab.
2. **Raw Frame Timing List**:
   ```json
   {
     "frames": [
       { "buildMs": 12.4, "rasterMs": 6.1 },
       { "buildMs": 18.2, "rasterMs": 14.5 }
     ]
   }
   ```
3. **Pre-aggregated Metrics JSON**:
   ```json
   {
     "frame_count": 120,
     "slow_frame_count": 5,
     "p90_frame_ms": 18.5
   }
   ```

Run trace analysis:

```bash
dart run flutter_dev_intelligence:flutter_dev performance --input trace.json
```

---

## Output Formats & File Exporting

### Terminal Format (Default)

Formatted terminal output with semantic colors, issue groupings, file locations, rule IDs, and confidence levels.

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project .
```

### JSON Format (Machine-Readable Automation)

Strict JSON on `stdout` without ANSI color codes or terminal decorations:

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project . --format json
```

### Markdown Format (GitHub Actions & PR Comments)

GitHub-flavored Markdown report for CI artifacts:

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project . --format markdown --output report.md
```

---

## Severity Levels & Exit Codes

### Diagnostic Severity

- **`HIGH` / `CRITICAL`**: Likely defect or runtime error (e.g. direct `setState` in build method, unconstrained scrollable in Flex container).
- **`MEDIUM`**: Meaningful architectural or performance risk (e.g. missing lockfile, nested scrollable without explicit physics).
- **`LOW`**: Minor code quality risk.
- **`INFO`**: Pattern detected or log processed clean (e.g. horizontal carousel inside vertical list, unmatched build log).

### CLI Exit Codes

- `0`: Execution completed successfully; no high or medium severity issues found.
- `1`: Execution completed successfully; one or more high or medium severity issues were found.
- `2`: Invalid arguments, missing file, or empty stdin.
- `3`: Diagnostic execution failure or I/O error.

---

## Optional AI Configuration & Privacy

`flutter_dev_intelligence` operates 100% locally by default.

AI provider integration is optional. When configured via the Dart API, diagnostic summaries can be enriched with AI suggestions. All outgoing requests pass through `SecretRedactor` to strip sensitive file paths, IP addresses, and API keys.

---

## Programmatic Dart API Usage

Consume `flutter_dev_intelligence` as a library in custom tooling:

```dart
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

Future<void> main() async {
  final report = await DoctorRunner.run(
    const DoctorOptions(projectPath: '.'),
  );

  if (report.issues.isNotEmpty) {
    print('Found ${report.issues.length} diagnostic issues:');
    print(DiagnosticReportRenderer.renderTerminal(report));
  }
}
```

---

## Maintainer & Contributor Workflow

Refer to [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing guidelines, and analyzer rule contribution patterns.

---

## License

This package is licensed under the [MIT License](LICENSE).
