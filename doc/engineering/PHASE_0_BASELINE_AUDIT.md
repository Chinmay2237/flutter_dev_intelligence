# Phase 0: Baseline Audit & Technical Debt Inventory for 1.0.0 Release

**Target Package:** `flutter_dev_intelligence`  
**Current Version:** `0.1.0-dev.3`  
**Target Release:** `1.0.0` Stable  
**Audit Date:** September 2026  
**Auditor Role:** Principal Dart/Flutter Package Architect, Static Analysis Engineer, CLI UX Engineer, & Release QA Lead

---

## 1. Executive Summary

`flutter_dev_intelligence` is an evidence-based developer diagnostics package for Dart and Flutter projects. It provides deterministic build log parsing, static Dart AST UI layout heuristics, frame-timing performance trace analysis, and project-wide dependency inspection.

This baseline audit evaluates the package across **architecture, diagnostic accuracy, public API stability, CLI UX, performance/security, and automated test coverage** to establish the foundation for hardening the codebase toward a stable `1.0.0` release.

### Key Audit Findings Summary
- **Verification Gates:** Current formatting (`dart format`), static analysis (`flutter analyze`), unit test suite (`flutter test`), example tests (`flutter test example`), and packaging dry-run (`dart pub publish --dry-run`) all pass with **0 warnings and 0 errors**.
- **Architecture:** Clear separation between CLI entrypoint (`bin/flutter_dev.dart`), diagnostic engines (`DoctorRunner`, `BuildLogParser`, `UiAstAnalyzer`, `PerformanceInvestigator`), domain models (`DiagnosticReport`, `DiagnosticIssue`), and renderers (`DiagnosticReportRenderer`).
- **API Surface Exposure:** The main barrel file `lib/flutter_dev_intelligence.dart` currently exports internal rule implementations (`src/ui_doctor/ui_ast_rule.dart`, `src/build_doctor/build_doctor_rule.dart`), which risks exposing internal AST visitors as public API before `1.0.0`.
- **Diagnostic Rules:** 12 build log rules, 7 UI AST rules, and 3 performance rules are active. Heuristics for horizontal scrollables and unmatched logs have been tuned to `INFO` severity to eliminate false positives.

---

## 2. Current Architecture Map

### Subsystem Flow & Layering

```
 ┌─────────────────────────────────────────────────────────┐
 │                   bin/flutter_dev.dart                  │
 │                  (CLI Entrypoint & Args)                │
 └────────────────────────────┬────────────────────────────┘
                              │
                              ▼
 ┌─────────────────────────────────────────────────────────┐
 │                   Diagnostic Engines                    │
 │ ┌──────────────────┐ ┌────────────────────────────────┐ │
 │ │  DoctorRunner    │ │    BuildLogParser & Registry   │ │
 │ └──────────────────┘ └────────────────────────────────┘ │
 │ ┌──────────────────┐ ┌────────────────────────────────┐ │
 │ │  UiAstAnalyzer   │ │    PerformanceInvestigator     │ │
 │ └──────────────────┘ └────────────────────────────────┘ │
 └────────────────────────────┬────────────────────────────┘
                              │
                              ▼
 ┌─────────────────────────────────────────────────────────┐
 │                      Core Models                        │
 │  DiagnosticReport • DiagnosticIssue • EvidenceReference │
 └────────────────────────────┬────────────────────────────┘
                              │
                              ▼
 ┌─────────────────────────────────────────────────────────┐
 │              DiagnosticReportRenderer                   │
 │       Terminal (ANSI/TTY) • JSON • Markdown             │
 └─────────────────────────────────────────────────────────┘
```

### Module Responsibilities

| Directory / File | Layer | Primary Responsibility | Dependency Direction |
|---|---|---|---|
| `bin/flutter_dev.dart` | CLI | Command routing, argument parsing, exit code mapping | Imports `lib/flutter_dev_intelligence.dart` & `dart:io` |
| `lib/src/core/models.dart` | Core Models | Canonical JSON-serializable diagnostic data structures | Standalone (imports no package internal files) |
| `lib/src/core/config.dart` | Core Config | Version constant (`kPackageVersion`) & `DevIntelligenceConfig` | Standalone |
| `lib/src/core/secret_redactor.dart` | Core Security | Sanitizes API keys, tokens, IP addresses, and home paths | Standalone |
| `lib/src/core/auto_fix_engine.dart` | Core Utility | Dry-run diff generation and `.bak` file modification safety | Imports `core/models.dart` |
| `lib/src/build_doctor/` | Build Engine | Log RegEx parsing, `pubspec.yaml`, `pubspec.lock`, project scanner | Imports `core/models.dart` & `package:yaml` |
| `lib/src/ui_doctor/` | UI Engine | Dart AST static visitor analysis (`analyzer` package) | Imports `core/models.dart` & `package:analyzer` |
| `lib/src/performance/` | Perf Engine | Frame timing percentiles (p50/p90/p99) & DevTools trace parser | Imports `core/models.dart` |
| `lib/src/ai/` | AI Adapter | Optional `AiExplanationProvider` interface & mock fallback | Imports `core/models.dart` & `core/secret_redactor.dart` |

---

## 3. Current Feature Inventory

1. **`doctor` Command:** Project-level inspection scanning `pubspec.yaml`, `pubspec.lock` (classifying `direct main`, `direct dev`, `transitive`), static UI AST files in `lib/`, and optional build log files.
2. **`build-doctor` Command:** Deterministic build log parser targeting Android (Gradle, Kotlin, Manifest merge, NDK, Multidex) and iOS (Xcode, CocoaPods, Swift, code signing).
3. **`ui-doctor` Command:** Static AST layout heuristics detecting suspicious `setState()` inside build methods, unconstrained scrollables, misused `Expanded` widgets, oversized literal dimensions, and nested scrollable direction conflicts.
4. **`performance` Command:** Analyzes frame timing data from DevTools timeline JSON (`traceEvents`), raw frame timing arrays (`frames`), or pre-summarized metrics.
5. **Output Rendering:** Terminal output with semantic ANSI colors (`--color auto|always|never`), TTY auto-detection, strict JSON output (`--format json`), GitHub-flavored Markdown reports (`--format markdown`), and direct file writing (`--output`).
6. **Privacy & Security:** `SecretRedactor` normalizes local file paths (`~`) and redacts AWS/GCP/OpenAI tokens, Bearer headers, and IPv4 addresses.
7. **Auto-Fix Abstraction:** `AutoFixEngine` supporting `planFixes` (dry-run patch diffs) and `applyFixes` (guarded execution with `.bak` backups).

---

## 4. Rule Inventory & Diagnostic Accuracy

### A. Build Doctor Rules (`lib/src/build_doctor/build_doctor_rule.dart`)

| Rule ID | Category | Detection Method | Positive Match | Negative Match | Severity | Confidence | Test Coverage |
|---|---|---|---|---|---|---|---|
| `gradle_failure` | Build | RegEx pattern | `BUILD FAILED in 12s` | Clean build log | `HIGH` | 0.95 | Tested (`build_doctor_rule_test.dart`) |
| `kotlin_version_mismatch` | Build | RegEx pattern | `Module was compiled with an incompatible version of Kotlin` | Compatible Kotlin build | `HIGH` | 0.90 | Tested |
| `duplicate_class` | Build | RegEx pattern | `Duplicate class com.example.Foo found in modules` | Unique classes | `HIGH` | 0.95 | Tested |
| `android_sdk_missing` | Build | RegEx pattern | `SDK location not found. Define location with an ANDROID_HOME` | Configured SDK | `HIGH` | 0.90 | Tested |
| `manifest_merge_error` | Build | RegEx pattern | `Attribute application@icon value=... Manifest merger failed` | Valid manifest | `HIGH` | 0.90 | Tested |
| `desugaring_error` | Build | RegEx pattern | `Type-desugaring is enabled` / `coreLibraryDesugaring` | Valid desugaring | `HIGH` | 0.85 | Tested |
| `multidex_issue` | Build | RegEx pattern | `Cannot fit requested classes in a single dex file` | Small DEX method count | `HIGH` | 0.90 | Tested |
| `ios_signing` | Build | RegEx pattern | `Code signing is required for product type` | Valid signing profile | `HIGH` | 0.90 | Tested |
| `deployment_target_mismatch` | Build | RegEx pattern | `The iOS deployment target ... is set to 9.0` | Target >= 12.0 | `MEDIUM` | 0.85 | Tested |
| `missing_scheme` | Build | RegEx pattern | `The scheme ... does not exist` | Valid scheme | `HIGH` | 0.90 | Tested |
| `swift_compiler_error` | Build | RegEx pattern | `error: cannot find ... in scope` | Clean Swift build | `HIGH` | 0.90 | Tested |
| `unknown_log_pattern` | Build | Fallback when 0 rules match | Clean log text | Any matched error rule | `INFO` | N/A | Tested |

### B. UI AST Rules (`lib/src/ui_doctor/ui_ast_rule.dart`)

| Rule ID | Category | Detection Method | Positive Match | Negative Match | Severity | Confidence | Test Coverage |
|---|---|---|---|---|---|---|---|
| `ui_nested_horizontal_scrollable` | Layout | AST Visitor + `scrollDirection: Axis.horizontal` | Horizontal ListView inside vertical ListView | Single scrollable | `INFO` | 0.60 | Tested (`ui_ast_analyzer_test.dart`) |
| `ui_nested_scrollable` | Layout | AST Visitor + stack inspection | Vertical ListView inside vertical ListView without physics | Scrollable with `NeverScrollableScrollPhysics` | `MEDIUM` | 0.80 | Tested |
| `ui_nested_shrink_wrap` | Layout | AST Visitor + `shrinkWrap: true` | `shrinkWrap: true` inside parent scrollable | Un-nested shrinkWrap | `LOW` | 0.70 | Tested |
| `ui_unconstrained_scrollable` | Layout | AST Visitor + Parent Flex check | ListView inside Column without `Expanded` or `SizedBox` | ListView inside `Expanded` | `HIGH` | 0.90 | Tested |
| `ui_expanded_misuse` | Layout | AST Visitor + Parent ancestor check | `Expanded` inside `Stack` or `Container` | `Expanded` inside `Column`/`Row` | `HIGH` | 0.95 | Tested |
| `ui_oversized_dimension` | Layout | AST Visitor + Literal evaluation | `SizedBox(width: 5000)` | `SizedBox(width: 200)` | `MEDIUM` | 0.75 | Tested |
| `ui_suspicious_setstate` | Rebuild | AST Visitor + Method enclosure check | Direct `setState()` call inside `build()` method | `setState()` inside `onTap: () {}` callback | `HIGH` | 0.90 | Tested |

### C. Performance Rules (`lib/src/performance/performance_investigator.dart`)

| Rule ID | Category | Detection Method | Positive Match | Severity | Confidence | Test Coverage |
|---|---|---|---|---|---|---|
| `perf_slow_frame_p90` | Frame | Percentile math (`p90 > 16.67ms`) | `p90FrameMs = 24.5ms` | `MEDIUM` / `HIGH` | 0.88 | Tested (`performance_investigator_test.dart`) |
| `perf_build_bottleneck` | Rebuild | Threshold (`averageBuildMs > 8.33ms`) | `averageBuildMs = 12.1ms` | `MEDIUM` / `HIGH` | 0.85 | Tested |
| `perf_raster_bottleneck` | Performance | Threshold (`averageRasterMs > 8.33ms`) | `averageRasterMs = 14.2ms` | `MEDIUM` / `HIGH` | 0.84 | Tested |

---

## 5. Public API Inventory & Stability Assessment

The public API is currently exported via `lib/flutter_dev_intelligence.dart`:

```dart
// Public exports in lib/flutter_dev_intelligence.dart
export 'src/core/config.dart';
export 'src/core/models.dart';
export 'src/core/secret_redactor.dart';
export 'src/core/auto_fix_engine.dart';
export 'src/build_doctor/build_doctor.dart';
export 'src/build_doctor/build_doctor_cli.dart';
export 'src/build_doctor/build_doctor_rule.dart'; // <--- Exposed internal rule implementation
export 'src/build_doctor/doctor_runner.dart';
export 'src/build_doctor/log_parser.dart';
export 'src/build_doctor/project_scanner.dart';
export 'src/build_doctor/pubspec_analyzer.dart';
export 'src/build_doctor/pubspec_lock_analyzer.dart';
export 'src/build_doctor/reporting.dart';
export 'src/ai/ai_provider.dart';
export 'src/performance/performance_investigator.dart';
export 'src/ui_doctor/ui_doctor.dart';
export 'src/ui_doctor/ui_ast_analyzer.dart';
export 'src/ui_doctor/ui_ast_rule.dart';         // <--- Exposed internal rule implementation
```

### Breaking Change Risks & Stability Recommendations for 1.0.0
1. **Hide Internal Rule Implementation Exports:** `ui_ast_rule.dart` and `build_doctor_rule.dart` contain AST visitor helper methods and RegEx classes. For `1.0.0`, exports should expose high-level facades (`UiAstAnalyzer`, `BuildLogParser`, `DoctorRunner`, `DiagnosticReport`) while keeping AST visitor internals in `src/`.
2. **Immutability of Data Models:** `DiagnosticReport` and `DiagnosticIssue` fields are currently immutable `final` values, which is excellent for 1.0.0 stability.
3. **Dartdoc Coverage:** All top-level classes in `lib/src/core/models.dart` have Dartdoc comments. Ensure 100% Dartdoc coverage across all public exported symbols prior to 1.0.0.

---

## 6. CLI Inventory

### Commands & Options Matrix

| Command | Option / Flag | Accepted Input | Stdin Supported | Exit Codes | Description |
|---|---|---|---|---|---|
| `doctor` | `--project <path>` | Directory path | ❌ No | `0`, `1`, `2`, `3` | Full project inspection (`pubspec`, lockfile, UI AST, build logs) |
| `build-doctor` | `--log <path>` \| `--stdin` | Log text / pipe |  Yes | `0`, `1`, `2`, `3` | Parses build logs for deterministic compiler/tool errors |
| `ui-doctor` | `--project <path>` | Directory path | ❌ No | `0`, `1`, `2`, `3` | Static Dart AST layout heuristics on `lib/` directory |
| `performance` | `--input <path>` \| `--stdin` | Trace JSON / pipe |  Yes | `0`, `1`, `2`, `3` | Frame timing percentiles (p50/p90/p99) analysis |
| `--help` / `-h` | None | None | N/A | `0` | Prints CLI usage guidelines |
| `--version` / `-v` | None | None | N/A | `0` | Prints `flutter_dev_intelligence 0.1.0-dev.3` |

### CLI UX Features
- **Semantic Terminal Colors:** Cyan for headings/paths, Yellow for MEDIUM, Red for HIGH/CRITICAL, Green for clean success, Muted for rule IDs.
- **Color Policy Flags:** `--color auto` (TTY detection + `NO_COLOR` env var check), `--color always`, `--color never`, `--no-color`.
- **ANSI Isolation:** Machine-readable formats (`--format json` and `--format markdown`) and file outputs (`--output <path>`) contain zero ANSI color sequences.

---

## 7. Performance and Security Review

### Security & Privacy
- **Local-First Execution:** All diagnostic analyzers operate locally on file system paths or standard input. Zero network requests occur by default.
- **Secret Redaction (`SecretRedactor`):** Redacts Bearer tokens, AWS/GCP/OpenAI keys, IPv4 addresses, and normalizes user home directory paths (`/home/username` -> `~`).
- **File Safety in Auto-Fix Engine:** `AutoFixEngine.applyFixes()` creates `.bak` backups before modifying files and refuses to modify generated code or binary assets.

### Resource Usage & Performance Bounds
- **AST Parsing Overhead:** Uses Dart `package:analyzer` parseString/parseFile. Efficient for standard Flutter projects, but large monorepos with 1,000+ Dart files should have bounded folder traversal.
- **Trace JSON Stream Handling:** Parses JSON maps up to standard DevTools timeline size. Large timeline files (>50MB) parse via `jsonDecode`.

---

## 8. Test Inventory & Baseline Verification

### Baseline Execution Results (Run in Phase 0)

1. **Code Formatting Check:**
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
   *Result:* **PASS** (Formatted 39 files, 0 changed in 0.21s).

2. **Package Static Analysis:**
   ```bash
   flutter analyze
   ```
   *Result:* **PASS** (No issues found! Ran in 3.9s).

3. **Example Application Analysis:**
   ```bash
   flutter analyze example
   ```
   *Result:* **PASS** (No issues found! Ran in 3.3s).

4. **Package Unit & Integration Tests:**
   ```bash
   flutter test
   ```
   *Result:* **PASS** (All 78 tests passed!).

5. **Example Application Tests:**
   ```bash
   flutter test example
   ```
   *Result:* **PASS** (All widget tests passed!).

6. **Pub Package Validation Dry-Run:**
   ```bash
   dart pub publish --dry-run
   ```
   *Result:* **PASS** (0 warnings, 0 errors, compressed package size 53 KB).

---

## 9. Risk Classification & Technical Debt Inventory

### Critical Risks (0)
- *None identified in baseline audit. All quality gates pass clean.*

### High-Priority Issues (1.0.0 Candidate Hardenings)
1. **Public Barrel Export Surface:** `lib/flutter_dev_intelligence.dart` exposes internal AST rule visitor classes (`ui_ast_rule.dart`, `build_doctor_rule.dart`). For `1.0.0`, internal rules should be encapsulated.
2. **Monorepo Directory Bounds:** Ensure `UiAstAnalyzer.analyzeDirectory()` cleanly ignores `.dart_tool/`, `build/`, and generated `.g.dart` / `.freezed.dart` files during project-wide scanning.

### Medium-Priority Issues
1. **Dartdoc Completeness:** Complete Dartdoc documentation for all public model methods, copyWith constructors, and renderer options.
2. **Performance Large Trace Handling:** Add explicit maximum file-size check (e.g. 100MB) for `performance --input` to prevent out-of-memory errors on massive raw DevTools trace files.

---

## 10. Recommended Implementation Order Towards 1.0.0

1. **Phase 1: Architecture & API Encapsulation**
   - Refine `lib/flutter_dev_intelligence.dart` barrel file to export clean public facades while encapsulating internal AST visitor rules.
   - Add explicit generated file exclusions (`.g.dart`, `.freezed.dart`, `.pb.dart`) to static UI scanner.

2. **Phase 2: Data Model & Dartdoc Completion**
   - Ensure 100% Dartdoc coverage across all exported symbols.
   - Verify immutability and JSON schema serialization contracts.

3. **Phase 3: CLI & Error Guardrails**
   - Add max file size guardrails for log and trace input processing.
   - Verify process-level exit codes across edge cases.

4. **Phase 4: Release Quality Gates & 1.0.0 Tagging**
   - Final pass on `flutter test`, `flutter analyze`, and `dart pub publish --dry-run`.

---

## 11. Proposed 1.0.0 Acceptance Criteria

- [x] Zero static analysis warnings (`flutter analyze` passes clean).
- [x] Zero code formatting violations (`dart format` passes clean).
- [x] 100% test pass rate across unit, integration, and example app tests.
- [x] Machine-readable outputs (JSON & Markdown) contain 0 ANSI escape sequences.
- [x] Package publish dry-run passes with 0 warnings (`dart pub publish --dry-run`).
- [ ] Public library barrel file (`lib/flutter_dev_intelligence.dart`) exports only stable 1.0.0 public API surfaces.
- [ ] 100% Dartdoc documentation on all public exported APIs.
