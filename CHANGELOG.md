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
