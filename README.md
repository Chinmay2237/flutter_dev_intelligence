# Flutter Dev Intelligence

[![pub package](https://img.shields.io/pub/v/flutter_dev_intelligence.svg)](https://pub.dev/packages/flutter_dev_intelligence)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Offline-first diagnostics for Flutter and Dart build failures, UI quality, accessibility, assets, performance, and code health.**

Flutter Dev Intelligence is a deterministic diagnostic toolkit designed to help developers understand build failures and identify potential quality issues in Flutter and Dart projects.

It provides two tools:

- 🛠️ **Build Doctor**: Analyzes Flutter, Dart, Gradle, Java, CocoaPods, compiler, and dependency build logs to isolate primary root causes from cascading failures.
- 🎨 **UI Doctor**: Statically inspects Flutter source code and asset declarations for accessibility, asset path casing, oversized files, maintainability, and performance code smells.

Reports can be rendered as interactive **Terminal** output (with ANSI color & ASCII modes), structured **JSON** (for CI & machine automation), or clean **Markdown** (for GitHub PR comments).

---

## Choose Your Use Case

| If you want to... | Use Command |
|---|---|
| Diagnose why a Flutter, Dart, Gradle, Java, or CocoaPods build failed | `dart run flutter_dev_intelligence build-doctor` |
| Inspect Flutter UI code for accessibility, asset errors, and code smells | `dart run flutter_dev_intelligence ui-doctor` |
| Prevent UI regressions in CI quality gates | `dart run flutter_dev_intelligence ui-doctor --baseline --fail-on-new` |
| Generate machine-readable diagnostic reports for tooling or CI artifacts | `--format json --output report.json` |

---

## Key Features

* 🎯 **Primary Root-Cause Prioritization**: Distinguishes primary failure root causes from downstream cascading symptoms (such as `BUILD FAILED` or task execution errors).
* 🔎 **Evidence-Backed Findings**: Every finding includes exact log references, context lines, and defensible confidence levels.
* 🧩 **Static Source Analysis**: UI Doctor uses Dart analyzer-based AST inspection and project heuristics.
* 🔒 **Offline & Local-First**: Performs 100% deterministic analysis locally. Automatically redacts credentials, tokens, API keys, private RSA keys, and user home directory paths (`~`).
* 📄 **Multi-Format Reporting**: Renders reports in **Terminal** (with color/ASCII options), **JSON** (machine-readable), and **Markdown** (ideal for GitHub Actions and issue comments).

---

## Installation

### Option 1: Add to a Flutter or Dart Project (Recommended)

For a Flutter project:

```bash
flutter pub add --dev flutter_dev_intelligence
```

For a pure Dart project:

```bash
dart pub add --dev flutter_dev_intelligence
```

Then run via `dart run`:

```bash
dart run flutter_dev_intelligence --help
```

### Option 2: Global CLI Activation

To run the CLI from any terminal directory:

```bash
dart pub global activate flutter_dev_intelligence
```

Then run directly:

```bash
flutter_dev_intelligence --help
```

*(If the global executable is not recognized, ensure your shell `PATH` includes the pub-cache `bin` directory).*

---

## Quick Start

### 1. Analyze a Build Log (Build Doctor)

From a file:

```bash
dart run flutter_dev_intelligence build-doctor --log build.log
```

From standard input pipe (ideal for CI pipelines):

```bash
flutter build apk 2>&1 | dart run flutter_dev_intelligence build-doctor --stdin
```

### 2. Analyze a Flutter Project (UI Doctor)

Run from your Flutter project directory:

```bash
dart run flutter_dev_intelligence ui-doctor
```

Inspect a specific category scope (`accessibility`, `assets`, `performance`, `maintainability`):

```bash
dart run flutter_dev_intelligence ui-doctor --scope accessibility
```

### 3. Generate Reports

Output machine-readable JSON:

```bash
dart run flutter_dev_intelligence ui-doctor --format json --output ui-report.json
```

Generate a Markdown report:

```bash
dart run flutter_dev_intelligence build-doctor --log build.log --format markdown
```

---

## Build Doctor

Build Doctor analyzes raw or piped build logs, strips ANSI formatting, redacts sensitive tokens, parses build events, matches diagnostic rules, and prioritizes primary root causes.

### Supported Diagnostic Categories

| Category | Description | Example Rule IDs |
|---|---|---|
| **Pub & Dependency** | Version solving failures, SDK mismatches, incompatible constraints | `PUB_VERSION_SOLVING_FAILED`, `DART_SDK_CONSTRAINT_MISMATCH` |
| **Dart Compiler** | Unresolved imports, undefined identifiers, type mismatches, missing generated code | `DART_UNRESOLVED_IMPORT`, `DART_MISSING_GENERATED_FILE` |
| **Android & Gradle** | Maven resolution failures, missing Android SDKs, Java/Gradle version mismatches | `GRADLE_DEPENDENCY_RESOLUTION_FAILED`, `JAVA_AGP_INCOMPATIBILITY` |
| **iOS & CocoaPods** | Pod spec resolution errors, deployment target conflicts, Xcode signing | `COCOAPODS_RESOLUTION_FAILED`, `IOS_DEPLOYMENT_TARGET_TOO_LOW` |

---

## UI Doctor (Static UI/UX & Code Health Inspector)

UI Doctor statically inspects Flutter source code (`lib/`) and `pubspec.yaml` asset declarations to detect potential code smells and accessibility gaps.

### Supported UI Doctor Diagnostics
* 📁 **Asset Validation**: Detects declared asset files missing from disk, letter-case mismatches (`UI_ASSET_CASE_MISMATCH`), and oversized assets (`UI_ASSET_OVERSIZED`).
* 🧹 **Code Health**: Detects unguarded `print()` and `debugPrint()` statements left in production source code (`UI_DEBUG_PRINT_IN_PROD`), respecting `kDebugMode` condition checks.
* 📐 **Maintainability**: Flags oversized `build()` methods (`UI_LARGE_BUILD_METHOD`) and large widget classes (`UI_LARGE_WIDGET_CLASS`).
* ⚡ **Performance Heuristics**: Flags `shrinkWrap: true` usages inside scrollable parent contexts (`UI_SHRINKWRAP_IN_SCROLLABLE`).
* ♿ **Accessibility**: Flags `Image` widgets missing `semanticLabel` descriptions or `excludeFromSemantics` flags (`UI_ACCESSIBILITY_MISSING_IMAGE_SEMANTICS`).

---

## Baseline & Regression Prevention

A baseline snapshot records existing project findings so CI quality gates can focus strictly on newly introduced issues.

### 1. Generate a Baseline Snapshot

Save a baseline snapshot JSON file:

```bash
dart run flutter_dev_intelligence ui-doctor --generate-baseline
```

*(Saves to `.flutter_dev_intelligence_baseline.json` by default, or specify `--generate-baseline=path/to/baseline.json`).*

### 2. Compare Against Baseline in CI

Compare current scan results against the baseline snapshot and fail CI only if new findings exist:

```bash
dart run flutter_dev_intelligence ui-doctor --baseline --fail-on-new
```

If new findings are detected, the CLI outputs a baseline diff summary and exits with code `1`.

---

## Configuration (`.flutter_dev_intelligence.yaml`)

Custom project settings can be defined in a `.flutter_dev_intelligence.yaml` file in your project root directory.

### Configuration Example

```yaml
version: 1

# Disable specific diagnostic rules
rules:
  disabled:
    - UI_DEBUG_PRINT_IN_PROD

# Configure path exclusions (globs supported)
paths:
  exclude:
    - 'build/**'
    - '.dart_tool/**'
    - '**/generated/**'
    - '**/*.g.dart'
    - '**/*.freezed.dart'
  exclude_tests: false
  exclude_generated: true

# Add targeted suppression rules
suppressions:
  - rule: "UI_ASSET_MISSING_FILE"
    file: "lib/features/dynamic_assets.dart"
    reason: "Assets are downloaded dynamically at runtime"
    owner: "@team-lead"

# Analysis threshold settings
analysis:
  severity_threshold: info
  confidence_threshold: 0.0
```

---

## CI Integration

### GitHub Actions Example

```yaml
name: Flutter Project Health & Diagnostics

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  diagnostics:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter SDK
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install Dependencies
        run: flutter pub get

      - name: Run UI Doctor Diagnostics (Quality Gate)
        run: |
          dart run flutter_dev_intelligence ui-doctor \
            --format json \
            --output ui-report.json \
            --baseline \
            --fail-on-new
```

---

## Exit Codes

The CLI enforces explicit OS exit code contracts for CI pipeline compatibility:

| Exit Code | Meaning | Description |
|---|---|---|
| `0` | **Success / Passed** | Clean analysis, no errors found, or baseline check passed. |
| `1` | **Diagnostic Failure** | Findings with `error` or `critical` severity detected, or new baseline issues found (`--fail-on-new`). |
| `2` | **CLI / Usage Error** | Missing log file, invalid arguments, or missing target directory. |
| `3` | **System / I/O Error** | Output file write failure (e.g. permission denied) or unhandled runtime exception. |

---

## What This Package Does Not Do

Flutter Dev Intelligence is a static rule-based diagnostic tool. It does not replace:
- Official Flutter or Dart static analyzer diagnostics (`dart analyze`).
- Native Gradle, Xcode, CocoaPods, or Java build toolchains.
- Dynamic runtime performance profiling (DevTools).
- Real-device UI testing or automated integration tests.
- Human code review.

UI Doctor findings are recommendations based on source patterns and project configuration. They should be reviewed in the context of your application.

---

## Offline & Privacy Guarantee

Flutter Dev Intelligence is designed for local, offline-first analysis.

- The diagnostic engine runs 100% locally on your machine or CI runner.
- It does not transmit source code, build logs, or environment metrics to any cloud service, remote server, or telemetry provider.
- No AI API keys or network access are required for core analysis.
- Secret redaction automatically strips credential-like patterns, tokens, and home directory paths (`~`) before rendering reports.

---

## Dart API Usage

You can also use `flutter_dev_intelligence` programmatically in custom Dart scripts or developer tooling:

```dart
import 'dart:io';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

Future<void> main() async {
  final logContent = await File('build.log').readAsString();

  final report = await BuildDoctor.analyzeLog(
    logContent,
    projectName: 'my_flutter_app',
  );

  print('Total Findings: ${report.findings.length}');
  print('Primary Root Causes: ${report.primaryFindings.length}');

  for (final finding in report.primaryFindings) {
    print('[${finding.id}] ${finding.title}');
    print('Likely Cause: ${finding.likelyCause}');
  }
}
```

---

## Development

Run static analysis:

```bash
dart analyze
```

Run unit and integration test suite:

```bash
dart test
```

Validate package publishing status:

```bash
dart pub publish --dry-run
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
