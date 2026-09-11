# Phase 3 Implementation Plan

## 1. Existing Architecture Summary
The repository is a library-first Flutter package with a small but meaningful core and a few early developer-tooling modules. The package currently exposes a public top-level API from `lib/flutter_dev_intelligence.dart`, has immutable configuration, shared diagnostic models, secret redaction, build log detection, UI overflow heuristics, and a minimal performance session/tracing model.

This is healthy as a foundation, but it remains a developer-preview prototype rather than a real feature-complete CLI tool.

## 2. Existing Reusable Components
The following are already useful and should be preserved:

- `DevIntelligenceConfig`
- `DiagnosticIssue`
- `DiagnosticReport`
- `EvidenceReference`
- `FixSuggestion`
- `SecretRedactor`
- `BuildDoctor.detectIssueFromLog`
- `UiDoctor.inspectViewport`
- `PerformanceInvestigator`
- The top-level public exports from `flutter_dev_intelligence.dart`
- The basic unit tests covering core models, redaction, build detection, and UI overflow checks

## 3. Planned New Modules
The Phase 3 work should add the missing real functionality without replacing what already works.

### 3.1 Project scanning
Add a project inspection layer for real directories and file detection:

- `ProjectInspectionResult`
- `FlutterProjectScanner`
- Safe path validation and project detection
- `pubspec.yaml` presence checks
- Platform folder detection
- Structure summary generation

### 3.2 Dependency and manifest analysis
Add a dependency analysis engine:

- `PubspecAnalyzer`
- `DependencySummary`
- `DependencyIssue`
- `pubspec.yaml` and `pubspec.lock` inspection
- direct/dev/override dependency summaries
- SDK constraint checks for Dart and Flutter

### 3.3 Build log parsing rules
Expand the build doctor from a single pattern into a rule engine that can parse multiple log styles:

- `BuildLogRule`
- `BuildLogParser`
- `BuildIssueDetector`
- Rule IDs for common patterns like Kotlin/Gradle mismatch, duplicate classes, missing imports, asset issues, and general Flutter tool failures

### 3.4 CLI experience
Add a more usable CLI command structure:

- `doctor`
- `build doctor`
- `report`
- `--project`
- `--log`
- `--format`
- `--output`
- `--help`
- `--version`

### 3.5 Report exporters
Add exported report generation to produce:

- terminal output
- JSON output
- Markdown output

### 3.6 UI static analysis expansion
Add a small but real static rule set focused on high-signal heuristics:

- icon-only buttons without labels
- suspicious nested scrolling patterns
- hardcoded text without localization cues
- fixed-width overflow risks
- heavy synchronous work in build methods

### 3.7 Performance runtime improvements
Add bounded session metrics and actual frame timing collection support where available using Flutter scheduler APIs.

### 3.8 AI boundary layer
Add a safe optional provider abstraction that is disabled by default and validated.

## 4. Public API Impact
The current public API is workable and should stay. New functionality can be added without altering existing stable names where possible.

Planned additions:

- `FlutterProjectScanner`
- `PubspecAnalyzer`
- `BuildLogParser`
- `DiagnosticRule`
- `ReportExporter`
- `AiProvider` (optional, feature-gated)

These should remain minimal and documented honestly.

## 5. Dependency Impact
This phase should avoid unnecessary third-party dependencies.

Priority: keep the package lightweight.

Likely additions, if needed:

- `yaml` package for `pubspec.yaml` parsing is a reasonable choice.
- No heavy AI SDK should be added to the core package.

## 6. Test Strategy
Testing should remain focused on real behavior:

- Project detection against temp directories
- `pubspec.yaml` parsing with valid and invalid fixtures
- Build-log parsing with realistic fixture files
- CLI command output and exit codes
- Report generation for JSON/Markdown/terminal
- UI rules against small source snippets
- Performance calculation logic tested without needing a full app

## 7. Known Technical Limitations
- This project is not yet a complete full-stack diagnostics platform.
- Frame timing requires specific Flutter runtime APIs and cannot be fully validated in a pure Dart unit test.
- AI remains optional and should not be required for any deterministic diagnostics.
- We should limit the scope to a real developer-preview tool rather than advertising a complete platform.

## 8. Implementation Order
1. Project scanner + `pubspec` analyzer
2. Build log parser and fixture-driven rule engine
3. Report exporters and CLI output
4. UI static analysis rules
5. Performance improvements and calculations
6. AI boundary abstraction
7. Example app and final docs
8. Validation and publication dry-run

This order keeps the foundation usable while expanding capabilities one layer at a time.
