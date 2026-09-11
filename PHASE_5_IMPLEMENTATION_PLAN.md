# Phase 5 Implementation Plan

Phase 5 advances the verified Flutter Dev Intelligence developer preview toward a Production Candidate. It expands static UI analysis, lockfile parsing, Build Doctor diagnostic rules, runtime performance insights, optional AI provider integration, safe automated suggestions, report visualization, CLI sub-commands, privacy redaction, and CI automation.

## 1. Workstream Summary Matrix

| Workstream | Current State | Target State | Implementation Approach | Tests | Priority |
|------------|---------------|--------------|--------------------------|-------|----------|
| Static UI Analysis | 3 basic inline rules in `UiAstAnalyzer` | Modular `UiAstRule` registry with 7+ high-confidence layout & code rules (unconstrained scrollables, Expanded misuse, nested scaffolds, suspicious setState, shrinkWrap, oversized dimensions) | Create `UiAstRule` base class & `UiAstRuleRegistry`. Use `analyzer` package AST visitor (`parseString`, `RecursiveAstVisitor`) with line/column locations, confidence levels, and explicit static source classification. | Fixtures under `test/fixtures/ui/` for valid layouts, nested scrollables, unconstrained flex, Expanded misuse, false positives. Unit tests for matching, locations, and deduplication. | P0 |
| Lockfile Analysis | Custom line parser with fragile section checks | Full YAML lockfile parsing using `yaml` package | Parse `pubspec.lock` with `yaml` package into structured package objects (`hosted`, `git`, `path`, `sdk`, version, dependency kind `direct`/`dev`/`transitive`). Handle malformed YAML, comments, quoted strings. | Fixtures under `test/fixtures/lockfiles/` covering hosted, git, path, SDK, missing, malformed, and mismatch scenarios. | P0 |
| Build Doctor | Single `BuildLogParser` class with inline regex | Modular `BuildDoctorRule` registry with 20+ rules for Flutter/Dart, Android, and iOS build errors | Extract rules into `BuildDoctorRuleRegistry` hierarchy. Each rule provides stable ID, title, severity, category, source, evidence extractor, suggestions, confidence, and doc refs. | Positive & negative fixtures under `test/fixtures/build_logs/` for Android (Gradle, Kotlin, Java, SDK, multidex, duplicate class), iOS (Xcode, CocoaPods, signing, targets), and Dart/Flutter compiler errors. | P1 |
| Performance Insights | Bounded sample collector with basic p50/p90/p99 calculations | Full frame timing aggregation, build vs raster breakdown, budget violation detection, evidence-backed recommendations, and session comparisons | Add pure calculations for build/raster percentiles, budget violation count, and threshold-driven recommendation generator. Support session comparison. | Unit tests for percentile math, empty metrics, threshold recommendations, session delta calculation, and bounded storage. | P1 |
| AI Provider Boundary | Basic abstract `AiProvider` interface with request/response models | Safe `AiAnalysisService` orchestrator with secret redaction, user opt-in enforcement, configurable providers, and advisory response decoration | Implement `AiProviderConfig` & `AiAnalysisService`. No network calls by default. Provide `MockAiProvider` for testing & explicit registration pattern for external AI models. | Tests for secret redaction before transmission, opt-in gating, mock provider invocation, malformed response handling, and advisory labeling. | P2 |
| Safe Automated Fix Suggestions | `FixSuggestion` with action & details strings only | Structured `FixSuggestion` with risk levels, proposed changes/diffs, automation safety flags, and an opt-in `AutoFixEngine` | Extend `FixSuggestion` with `riskLevel`, `proposedChange`, `isSafeToAutomate`, `requiresUserConfirmation`. Create `AutoFixEngine` with dry-run mode, backup creation (`.bak`), and strict safety checks. | Tests for suggestion serialization, dry-run diff generation, backup file creation, and strict refusal to touch uncommitted/generated files without opt-in. | P1 |
| Reporting & Visualization | Terminal, JSON, Markdown renderers without explicit schema versioning | Schema-versioned reports (`schemaVersion: '1.0'`) with diagnostic grouping by severity/source/category and comprehensive summaries | Update `DiagnosticReport` model with schema versioning, grouping utilities, and enriched Markdown/Terminal output renderers. | JSON schema validity tests, Markdown snapshot tests, terminal output formatting tests. | P1 |
| CLI Experience | CLI flags for `doctor` and `build-doctor` | Comprehensive CLI command set (`doctor`, `build-doctor`, `ui-doctor`, `performance`) with sub-command help and shell-friendly JSON | Update `bin/flutter_dev.dart` with robust argument parsing for sub-commands, format options, quiet/verbose flags, and clear exit codes (0, 1, 2, 3). | CLI process integration tests for all sub-commands, argument errors, and exit codes. | P1 |
| Privacy & Redaction | Basic Regex replacement in `SecretRedactor` | Dedicated `PrivacyRedactor` covering API keys, bearer tokens, passwords, auth headers, private URLs, env vars, and sensitive file paths | Enhance `SecretRedactor` / `PrivacyRedactor` to scan and sanitize all report evidence, build logs, and AI payloads. | Tests against representative fake secrets, credentials, tokens, and private URL formats. | P1 |
| CI/CD & Example App | Local testing only; minimal example without platform runners | Automated GitHub Actions CI workflow & updated example app demonstrating package capabilities | Create `.github/workflows/ci.yml`. Update `example/lib/main.dart` with working demonstrations of scanner, UI AST analyzer, performance collector, and reporting. | CI workflow verification and `flutter analyze example` / `flutter test example`. | P2 |

---

## 2. Detailed Architectural Component Specifications

### 2.1 Static UI AST Analyzer (`lib/src/ui_doctor/`)
- `UiAstRule` base class:
  - `String get id`
  - `String get title`
  - `DiagnosticCategory get category`
  - `DiagnosticSeverity get severity`
  - `double get defaultConfidence`
  - `List<DiagnosticIssue> checkNode(AstNode node, String filePath, LineInfo lineInfo)`
- Specific Rule Classes:
  1. `UiNestedScrollableRule` (`ui_nested_scrollable`): Detects scrollable widgets (ListView, GridView, SingleChildScrollView, CustomScrollView) nested within other scrollables.
  2. `UiNestedShrinkWrapRule` (`ui_nested_shrink_wrap`): Detects `shrinkWrap: true` on nested scrollable lists.
  3. `UiUnconstrainedScrollableRule` (`ui_unconstrained_scrollable`): Detects ListView/GridView directly inside Column/Row without Expanded/Flexible or explicit constraints.
  4. `UiExpandedMisuseRule` (`ui_expanded_misuse`): Detects `Expanded` or `Flexible` widgets used outside a `Row`, `Column`, or `Flex` parent.
  5. `UiOversizedDimensionRule` (`ui_oversized_dimension`): Detects hardcoded width/height > 1000 pixels.
  6. `UiNestedScaffoldRule` (`ui_nested_scaffold`): Detects `Scaffold` or `MaterialApp` nested inside another `Scaffold` or `MaterialApp`.
  7. `UiSuspiciousSetStateRule` (`ui_suspicious_setstate`): Detects `setState` invocations inside widget `build()` methods.
- `UiAstRuleRegistry`: Contains all default rules and manages AST traversal.

### 2.2 Lockfile Analysis (`lib/src/build_doctor/pubspec_lock_analyzer.dart`)
- Integrate `yaml: ^3.1.2` in `pubspec.yaml`.
- Parse `pubspec.lock` with `loadYaml`.
- Extract package name, version, source (`hosted`, `git`, `path`, `sdk`), dependency kind (`direct main`, `direct dev`, `transitive`), and description metadata.
- Gracefully handle malformed YAML, empty files, missing files, and mismatched dependencies between `pubspec.yaml` and `pubspec.lock`.

### 2.3 Build Doctor Rule Registry (`lib/src/build_doctor/`)
- `BuildDoctorRule` abstract base class:
  - `String get id`
  - `String get title`
  - `DiagnosticCategory get category`
  - `DiagnosticSeverity get severity`
  - `String get description`
  - `double get confidence`
  - `bool matches(String logContent)`
  - `DiagnosticIssue createIssue(String logContent)`
- Rule Registry covering:
  - **Flutter/Dart**: `analyzer_error`, `missing_import`, `null_safety_error`, `dependency_resolution_failed`, `flutter_tool_failure`, `asset_error`.
  - **Android**: `gradle_failure`, `kotlin_version_mismatch`, `java_runtime_mismatch`, `android_sdk_missing`, `duplicate_class`, `manifest_merge_error`, `desugaring_error`, `multidex_issue`.
  - **iOS**: `xcode_build_failure`, `cocoapods_failure`, `deployment_target_mismatch`, `signing_configuration`, `missing_scheme`, `swift_compiler_error`.

### 2.4 Performance Insights (`lib/src/performance/`)
- Enhance `FrameTimingSummary` with:
  - Build vs Raster time breakdown.
  - Slow frame counts (>16.67ms and >33.33ms).
  - Percentiles: p50, p90, p99.
  - Threshold-driven heuristic recommendations (e.g., high raster time -> check shader compilation or heavy image repaints).
  - Session comparison utility (`compareSessions(FrameTimingSummary before, FrameTimingSummary after)`).

### 2.5 Optional AI Provider Boundary (`lib/src/ai/`)
- `AiProviderConfig`: `enabled`, `apiKey`, `modelName`, `timeoutDuration`, `maxTokens`.
- `AiAnalysisService`:
  - Validates user opt-in (`enabled == true`).
  - Redacts credentials from evidence via `PrivacyRedactor`.
  - Invokes `AiProvider.analyze()`.
  - Attaches advisory tag and confidence score to output.
- `MockAiProvider`: Implements `AiProvider` for testing without network requests.

### 2.6 Safe Automated Fix Suggestions (`lib/src/core/`)
- Enriched `FixSuggestion` with `riskLevel`, `proposedChange`, `isSafeToAutomate`, `requiresUserConfirmation`.
- `AutoFixEngine`:
  - `dryRun(List<DiagnosticIssue> issues)`: Generates diff/summary of changes without writing.
  - `applyFixes(List<DiagnosticIssue> issues, {bool createBackups = true})`: Applies safe fixes with `.bak` backups.

### 2.7 CLI Sub-Commands (`bin/flutter_dev.dart`)
- Sub-commands:
  - `doctor`: Complete project check (scanner, pubspec, lockfile, static UI, optional build log).
  - `build-doctor`: Targeted build log diagnostic runner.
  - `ui-doctor`: Targeted static UI AST analysis runner.
  - `performance`: Targeted performance report runner.
- Flags: `--project`, `--log`, `--input`, `--format` (terminal, json, markdown), `--output`, `--quiet`, `--verbose`, `--no-ai`.

### 2.8 Privacy & Secret Redaction (`lib/src/core/secret_redactor.dart`)
- `PrivacyRedactor`: Sanitizes API keys, bearer tokens, passwords, private URLs, authorization headers, environment variables, and user home directory paths.

### 2.9 CI/CD & Example App
- Workflow file: `.github/workflows/ci.yml`.
- Example update: `example/lib/main.dart` with API demonstrations for all modules.

---

## 3. Verification Plan

### Automated Commands
```bash
dart format --output=none --set-exit-if-changed .
dart analyze
flutter analyze
flutter analyze example
flutter test --reporter expanded
flutter test example
dart pub publish --dry-run
```

### Process CLI Tests
- Test `flutter-dev doctor --project .`
- Test `flutter-dev ui-doctor --project .`
- Test `flutter-dev build-doctor --log test/fixtures/build_logs/duplicate_class.log`
- Test `flutter-dev performance --input trace.json`
