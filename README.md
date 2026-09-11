# Flutter Dev Intelligence

[![pub package](https://img.shields.io/pub/v/flutter_dev_intelligence.svg)](https://pub.dev/packages/flutter_dev_intelligence)
[![Dart SDK](https://img.shields.io/badge/dart-%3E%3D3.11.5-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D1.17.0-blue.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

An evidence-based developer diagnostics toolkit for Flutter applications. Inspect build logs, Dart AST static UI patterns, dependency lockfiles, and performance frame traces with structured, machine-readable diagnostics.

---

## Key Features

- 🔍 **Project & Lockfile Diagnostics:** Validates package structure, dependency kinds (`direct main`, `direct dev`, `transitive`), and lockfile consistency while properly excluding SDK constraints (`environment.sdk`, `environment.flutter`).
- 🎨 **Dart AST Static UI Analysis:** Precise static analysis for common Flutter UI pitfalls:
  - Direct build-time `setState()` calls (with boundary detection for callbacks like `onTap` / `onPressed`).
  - Contextual nested scrollables (accounting for `NeverScrollableScrollPhysics`, horizontal carousels, Slivers, and bounded containers).
  - Unconstrained scrollables in Flex containers (`Column` / `Row`).
  - Misused `Expanded` / `Flexible` widgets and oversized literal pixel dimensions.
- 🛠️ **Build Log Engine:** Rule-based parser for Android (Gradle, Kotlin, Manifest, NDK) and iOS (Xcode, CocoaPods, Swift, code signing) build logs.
- ⚡ **Performance Trace Investigator:** Frame timing analysis (p50, p90, p99, build vs raster bottleneck detection).
- 💻 **Production Developer CLI:** Semantic ANSI terminal colors (`--color auto|always|never`), TTY auto-detection, ASCII fallbacks, `--stdin` pipe support, `--format terminal|json|markdown`, and saved report export (`--output`).
- 🛡️ **Read-Only & Privacy First:** All diagnostic commands are strictly read-only by default. Includes `SecretRedactor` for sanitizing logs before external sharing.

---

## Installation

Add `flutter_dev_intelligence` to your package's `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_dev_intelligence: ^0.1.0-dev.2
```

Then fetch dependencies:

```bash
flutter pub get
```

---

## Quick Start (CLI)

Run project-wide diagnostics from any Flutter or Dart project root:

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project .
```

### CLI Command Summary

| Command | Usage | Description |
|---|---|---|
| `doctor` | `flutter-dev doctor [--project <path>]` | Complete project diagnosis (`pubspec`, lockfile, static UI, logs) |
| `build-doctor` | `flutter-dev build-doctor (--log <path> \| --stdin)` | Analyze Flutter/Dart build logs |
| `ui-doctor` | `flutter-dev ui-doctor [--project <path>]` | Static Dart AST UI quality heuristics |
| `performance` | `flutter-dev performance (--input <json> \| --stdin)` | Analyze frame timing trace JSON |

---

## Piping and Stdin Integration

`flutter_dev_intelligence` supports standard input (`--stdin`) for CI/CD pipelines and interactive shell workflows:

### 1. Pipe `flutter analyze` or build logs into `build-doctor`:

```bash
flutter analyze 2>&1 | dart run flutter_dev_intelligence:flutter_dev build-doctor --stdin
```

```bash
flutter build apk 2>&1 | dart run flutter_dev_intelligence:flutter_dev build-doctor --stdin
```

### 2. Pipe performance trace JSON into `performance`:

```bash
cat trace.json | dart run flutter_dev_intelligence:flutter_dev performance --stdin
```

---

## Output Formats & Exporting

### Terminal Format (Default)

Formatted terminal output with semantic colors, clear issue groupings, file locations, rule IDs, and confidence levels.

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project .
```

### JSON Format (Machine-Readable Automation)

Clean JSON on `stdout` without ANSI color pollution or spinners, perfect for CI/CD assertions:

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project . --format json
```

### Markdown Format (GitHub & PR Comments)

GitHub-flavored Markdown tables and issue summaries for PR comments:

```bash
dart run flutter_dev_intelligence:flutter_dev doctor --project . --format markdown --output report.md
```

---

## Example Output

### Terminal Mode

```
Flutter Dev Intelligence
────────────────────────────────────────────
Project     my_flutter_app
Command     doctor
Duration    412 ms

Summary
────────────────────────────────────────────
  Issues       2
  High         1
  Medium       1
  Low          0

Issues
────────────────────────────────────────────

HIGH  setState called directly inside build method
      lib/features/home/home_screen.dart:42

      setState() was invoked directly inside the widget build() method.
      This causes infinite build loops and immediate runtime crashes.

      Rule: ui_suspicious_setstate
      Confidence: 95%
      Action: Move setState() calls into event handlers (onTap, onPressed) or lifecycle hooks.

MEDIUM  Unconstrained scrollable inside Row or Column
        lib/features/settings/settings_page.dart:88

        ListView is placed directly inside a Column without an Expanded or Flexible wrapper.

      Rule: ui_unconstrained_scrollable
      Confidence: 85%

Next steps
────────────────────────────────────────────
Review findings in context. Static diagnostics are heuristic.
```

---

## Dart API Usage

You can also consume `flutter_dev_intelligence` as a library within your Dart tools or test suites:

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

## Troubleshooting

### 1. `Dependencies declared in pubspec.yaml but absent from pubspec.lock: sdk`
This issue was fixed in `v0.1.0-dev.2`. Upgrade to the latest version. Environment SDK constraints (`environment.sdk`) are no longer misidentified as missing pub packages.

### 2. `setState()` reported inside callbacks (`onTap`, `onPressed`)
This false positive was fixed in `v0.1.0-dev.2`. The AST diagnostic engine now performs parent closure chain analysis to ignore `setState()` calls enclosed within callback functions.

### 3. Error: Standard input (stdin) was empty
When using `--stdin`, ensure input is piped into the process. For example:
```bash
cat build.log | dart run flutter_dev_intelligence:flutter_dev build-doctor --stdin
```

---

## License

This package is licensed under the [MIT License](LICENSE).
