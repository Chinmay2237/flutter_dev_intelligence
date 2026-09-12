## 1.0.0

### Production Release (Stable)
* **Configuration & Suppression System**: Documented YAML project schema (`flutter_dev_intelligence.yaml`) with support for enabled/disabled rules, severity/confidence thresholds, path exclusions (`exclude`, `include`, `exclude_tests`, `exclude_examples`, `exclude_generated`), scale limits, and fine-grained suppression rules with expiration dates.
* **AST UI Diagnostics**: 17 AST layout, lifecycle, accessibility, and resource management rules covering scrollable conflicts, unconstrained flex containers, controller disposal (`AnimationController`, `ScrollController`, `TextEditingController`, `FocusNode`), stream/timer cleanup, async mounted checks (`context.mounted`), and accessibility tooltips/labels.
* **Multi-Platform Build Log Engine**: 40 deterministic rules analyzing Android (Kotlin, AGP, Java major version mismatch, AAPT2, R8/ProGuard, NDK, multidex, duplicate class), iOS (Xcode, CocoaPods, provisioning signing, deployment targets, module imports, arm64/x86_64 arch mismatches), and Dart/Flutter tool exit logs.
* **Performance Trace Investigator**: DevTools Chrome trace (`traceEvents`) and frame timing array analysis with percentiles (p50..p99), hardware refresh rate budget evaluation (60Hz / 120Hz), UI vs GPU jank classification, and up to 50,000 trace event capping.
* **CLI Experience & Output Contracts**: Terminal layout with ANSI semantic colors, versioned 1.0 JSON report contract, and GitHub Flavored Markdown exporter.
* **Privacy, AI & Security**: Zero-network local-first privacy defaults, secret redaction engine (OpenAI, AWS, GCP, Bearer tokens, home paths), and opt-in AI advisory engine.
* **Scale Hardening**: Configurable scale limits (`maxFileSizeBytes`, `maxLogSizeBytes`, `maxTraceEvents`, `maxIssuesCount`), file size safeguards (> 2MB), 10MB head/tail log truncation, pre-compiled static regex instances, monorepo path deduplication, and fault-isolated rule execution.

## 0.1.0-dev.3

### Production Release & Packaging Enhancements
* Productized package architecture, public API docs, CLI exit-code semantics, and output formatting.
* Fixed false-positive nested scrollable reporting by reclassifying horizontal carousels as `INFO` severity (`Nested horizontal scrollable pattern detected`).
* Fixed build log fallback `unknown_log_pattern` severity (`INFO`) and exit code 0 when logs contain no matching error rules.
* Updated `.pubignore` to exclude build artifacts, `.dart_tool`, and temporary reports, reducing pub.dev archive size from 40 MB down to ~50 KB.

## 0.1.0-dev.2

### Lockfile & Dependency Analyzer Fixes
* Refactored `PubspecAnalyzer` to use `loadYaml` for authoritative dependency map parsing.
* Fixed false-positive `Dependencies declared in pubspec.yaml but absent from pubspec.lock: sdk` by excluding SDK pseudo-packages (`sdk`, `flutter`, `sky_engine`) and environment constraints.

### Static UI Diagnostic Engine Improvements
* Refined `UiSuspiciousSetStateRule` with AST parent traversal to distinguish direct build-time `setState()` calls from callback/closure invocations (`onTap`, `onPressed`, event handlers, async callbacks).
* Enhanced `UiNestedScrollableRule` with contextual checks for `NeverScrollableScrollPhysics`, horizontal carousels (`scrollDirection: Axis.horizontal`), Slivers inside `CustomScrollView`, and bounded parent containers (`SizedBox`, `Expanded`, `Flexible`).

### CLI Architecture & Pipe / Stdin Support
* Added `--stdin` support for `build-doctor` and `performance` commands to enable stdin pipe workflows (`flutter analyze 2>&1 | dart run ...` and `cat trace.json | dart run ...`).
* Enforced option validation (rejecting `--stdin` combined with `--log` or `--input`), non-empty stdin validation, and actionable error messages with clean exit codes (0 for success, 1 for issues found, 2 for argument/usage error, 3 for runtime error).

### Terminal UX, Semantic Colors & Exporters
* Implemented ANSI semantic color system with TTY auto-detection, `NO_COLOR` environment variable support, and `--color auto|always|never` / `--no-color` options.
* Added ASCII symbol fallbacks (`✓`, `!`) and ANSI code stripping for saved file output (`--output <path>`).
* Centralized package version (`kPackageVersion = '0.1.0-dev.2'`) across CLI, `DiagnosticReport` models, and metadata.
* Upgraded Markdown exporter (`--format markdown`) and JSON exporter (`--format json`) for clean machine-readable integration without ANSI escape sequence pollution.

## 0.1.0-dev.1

### Foundation & Models
* Enriched `DiagnosticReport` with `schemaVersion: '1.0'`, `issuesBySeverity`, `issuesBySource`, and `issuesByCategory`.
* Added `FixRiskLevel` enum and updated `FixSuggestion` with automation safety metadata.

### Lockfile Analyzer
* Upgraded `PubspecLockAnalyzer` to use authoritative `package:yaml` parsing.
* Added classification for dependency kinds (`direct main`, `direct dev`, `transitive`) and source types (`hosted`, `git`, `path`, `sdk`).
* Added graceful error handling for missing and malformed lockfiles.

### UI AST Rule Engine
* Modularized UI AST static analysis into `UiAstRule` architecture and `UiAstRuleRegistry`.
* Implemented 7 layout rules: `ui_nested_scrollable`, `ui_nested_shrink_wrap`, `ui_unconstrained_scrollable`, `ui_expanded_misuse`, `ui_oversized_dimension`, `ui_nested_scaffold`, and `ui_suspicious_setstate`.

### Build Doctor Rule Registry
* Introduced extensible `BuildDoctorRule` architecture with `BuildDoctorRuleRegistry`.
* Added 20+ specialized diagnostic rules covering Android Gradle, Kotlin versions, duplicate classes, Manifest merges, NDK, iOS Xcode/Swift compiler errors, CocoaPods, and code signing.

### Performance Insight Enhancements
* Added build vs. raster timing breakdown in `FrameTimingSummary`.
* Added session-to-session performance comparison with `FrameTimingComparison`.
* Implemented automated recommendation generator (`perf_slow_frame_p90`, `perf_build_bottleneck`, `perf_raster_bottleneck`).

### Privacy & AI Boundary
* Implemented `PrivacyRedactor` alias for `SecretRedactor` with credentials, Bearer tokens, private URLs, cloud keys (AWS/GCP/OpenAI), and home directory path normalization (`~`).
* Implemented `AiProviderConfig`, `MockAiProvider`, and `AiAnalysisService` enforcing local-first, opt-in AI analysis (`enabled == false` by default).

### Safe Auto-Fix Engine
* Implemented `AutoFixEngine` with `planFixes` (dry-run unified diffs) and `applyFixes` (creates `.bak` backups before write).
* Enforced safety guardrails preventing automated edits to high-risk, sensitive, or generated files.

### Dedicated CLI Sub-commands
* Added dedicated CLI sub-commands: `doctor`, `build-doctor`, `ui-doctor`, and `performance`.
* Supported flags: `--project`, `--log`, `--input`, `--format` (terminal/json/markdown), `--output`, `--verbose`, `--quiet`, `--no-ai`.

## 0.0.1

* Initial Developer Preview release with core diagnostics, log parsing, and performance investigation tools.
