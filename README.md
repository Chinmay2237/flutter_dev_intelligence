# Flutter Dev Intelligence

[![pub package](https://img.shields.io/pub/v/flutter_dev_intelligence.svg)](https://pub.dev/packages/flutter_dev_intelligence)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Flutter Dev Intelligence** is an offline-first diagnostic toolkit that analyzes Flutter and Dart build logs, identifies likely root causes, separates cascading failures, extracts evidence, and generates actionable debugging reports.

---

## Key Features

* 🎯 **Primary Root-Cause Prioritization**: Distinguishes the primary root cause from downstream cascading failures (such as `BUILD FAILED` or `:compileDebugJavaWithJavac FAILED`).
* 🔎 **Evidence-Backed Findings**: Every finding includes exact log references, context lines, and defensible confidence levels.
* 🔒 **Offline & Local-First**: Performs 100% deterministic analysis locally. Automatically redacts secrets, tokens, private keys, and user home directory paths.
* 📦 **Zero Heavy Dependencies**: Lightweight design without heavy AST parsers or network dependencies.
* 📄 **Multi-Format Output**: Renders scannable reports in **Terminal** (with color/ASCII options), **JSON** (machine-readable), and **Markdown** (ideal for GitHub Actions and issue comments).

---

## Quick Start

### Installation

Add `flutter_dev_intelligence` to your `pubspec.yaml` or run:

```bash
flutter pub add flutter_dev_intelligence
```

### CLI Usage

Analyze a build log file:

```bash
dart run flutter_dev_intelligence build-doctor --log path/to/build.log
```

Analyze build log from standard input pipe (ideal for CI pipelines):

```bash
flutter build apk 2>&1 | dart run flutter_dev_intelligence build-doctor --stdin
```

Generate a JSON report for CI artifact archiving:

```bash
dart run flutter_dev_intelligence build-doctor --log build.log --format json --output report.json
```

Generate Markdown summary for GitHub PR / Issue comments:

```bash
dart run flutter_dev_intelligence build-doctor --log build.log --format markdown
```

---

## Supported Diagnostic Categories

| Category | Description | Example Rule IDs |
|---|---|---|
| **Pub & Dependency** | Version solving failures, SDK mismatches, incompatible constraints | `PUB_VERSION_SOLVING_FAILED`, `DART_SDK_CONSTRAINT_MISMATCH` |
| **Dart Compiler** | Unresolved imports, undefined identifiers, type mismatches, missing generated files | `DART_UNRESOLVED_IMPORT`, `DART_MISSING_GENERATED_FILE` |
| **Android & Gradle** | Maven dependency resolution failures, SDK missing, Java/Gradle version mismatches | `GRADLE_DEPENDENCY_RESOLUTION_FAILED`, `JAVA_AGP_INCOMPATIBILITY` |
| **iOS & CocoaPods** | Pod spec resolution errors, deployment target conflicts, signing issues | `COCOAPODS_RESOLUTION_FAILED`, `IOS_DEPLOYMENT_TARGET_TOO_LOW` |

---

## Dart API Usage

You can also use `flutter_dev_intelligence` programmatically inside Dart or Flutter tools:

```dart
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() async {
  final logContent = await File('build.log').readAsString();

  final report = await BuildDoctor.analyzeLog(
    logContent,
    projectName: 'my_flutter_app',
  );

  print('Total Findings: ${report.findings.length}');
  print('Primary Root Causes: ${report.primaryFindings.length}');

  for (final primary in report.primaryFindings) {
    print('Primary Cause: ${primary.title} [${primary.id}]');
    print('Likely Cause:  ${primary.likelyCause}');
  }
}
```

---

## Development & Testing

Run analysis and test suite:

```bash
flutter analyze
flutter test
```

Dry-run package publication:

```bash
dart pub publish --dry-run
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
