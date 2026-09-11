# flutter_dev_intelligence

Evidence-driven diagnostics for Flutter projects. This package is a developer preview: it combines deterministic project, dependency, build-log, UI heuristic, and runtime performance tools without requiring an AI service.

## Available

- Project and `pubspec.yaml` inspection.
- `pubspec.lock` package/source counts and declared-dependency consistency warnings.
- Experimental AST-backed UI heuristics for nested scrollables, nested `shrinkWrap`, and oversized literal dimensions.
- Deterministic build-log rules for Kotlin/Gradle, duplicate classes, compile errors, Android SDK, Java, dependency resolution, Xcode, CocoaPods, and signing.
- Terminal, valid JSON, and Markdown reports.
- Manual trace metrics through `PerformanceInvestigator`.
- Real Flutter frame timing through `FrameTimingCollector` when running inside a Flutter application.
- Frame timing p50, p90, p99, build/raster averages, worst-frame, and slow-frame summaries.
- Optional `AiProvider` boundary. No provider or network call is included.

## CLI

```bash
dart run bin/flutter_dev.dart --help
dart run bin/flutter_dev.dart --version
dart run bin/flutter_dev.dart doctor --project .
dart run bin/flutter_dev.dart doctor --project . --format json
dart run bin/flutter_dev.dart doctor --project . --format markdown --output report.md
dart run bin/flutter_dev.dart doctor --project . --log build.log
dart run bin/flutter_dev.dart build-doctor --log build.log
```

Exit codes are `0` for no detected issues, `1` for diagnostics, `2` for invalid usage or paths, and `3` for unexpected execution or output failures.

## Dart API

```dart
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

final report = await DoctorRunner.run(
	const DoctorOptions(projectPath: '.'),
);
print(DiagnosticReportRenderer.renderJson(report));
```

Runtime frame collection must run inside a Flutter app with initialized bindings:

```dart
final frames = FrameTimingCollector(maxSamples: 120);
frames.start();
// ... exercise the application ...
frames.stop();
final report = frames.generateReport();
```

## Limitations and privacy

This is a developer preview. Static UI analysis is experimental and conservative: it parses Dart AST syntax without resolving the full Flutter program, so it reports source heuristics rather than definitive runtime layout failures. The CLI does not provide automatic fixes. Frame timing is runtime-only and requires a Flutter application. AI is opt-in by architecture but has no built-in provider, credentials, or network behavior. Build-log evidence should be treated as potentially sensitive; use `SecretRedactor` before sending text to any external service. Reports do not persist raw logs automatically.

The example application under `example/` demonstrates package APIs rather than a complete mobile application and intentionally has no Android/iOS runner projects.

See the phase reports in this repository for current implementation evidence and remaining release work.
