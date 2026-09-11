# Phase 4 Implementation Plan

## 1. Current Architecture Summary
The repository is currently a library-first Flutter package with a stable model layer and a limited set of real diagnostics. The most useful reusable pieces are:

- immutable runtime config
- issue/report models with evidence and suggestions
- redaction utilities
- project directory scanner
- `pubspec.yaml` analyzer
- build log rule parser
- basic UI overflow heuristics
- performance session/tracing model
- CLI entrypoint scaffold

These pieces are valid starting points, but the product still lacks an integrated workflow and end-to-end command usage.

## 2. Existing Reusable Components
The following components should remain and be extended:

- `FlutterDevIntelligence`
- `DevIntelligenceConfig`
- `DiagnosticIssue`
- `DiagnosticReport`
- `BuildDoctor`
- `BuildLogParser`
- `FlutterProjectScanner`
- `PubspecAnalyzer`
- `PerformanceInvestigator`
- `UiDoctor`
- `SecretRedactor`
- `bin/flutter_dev.dart`

## 3. Missing Integrations
Core gaps to fix in this phase:

- CLI workflow is not yet end-to-end.
- `pubspec.lock` analysis is missing.
- Build log rules are too narrow.
- Reporting is not fully integrated with the CLI.
- Runtime frame timing is not yet real enough.
- UI static rules are limited.
- AI abstraction is missing.
- Example app is absent.

## 4. Proposed Implementation Sequence
1. Build the CLI workflow around a real diagnostic orchestration layer.
2. Add `pubspec.lock` analyzer and lockfile consistency checks.
3. Expand the Build Doctor rule engine with fixture-driven coverage.
4. Add report rendering for terminal, JSON, and Markdown outputs.
5. Add a bounded runtime frame-timing layer using Flutter scheduler APIs where supported.
6. Expand UI static analysis with a few high-confidence rules.
7. Add optional AI provider abstraction with redaction and validation.
8. Build a minimal example app.
9. Final documentation and validation.

## 5. Public API Impact
The public API should remain intentionally small. New additions should be focused and testable.

Likely additions:

- `DiagnosticReportExporter`
- `ProjectDiagnosticEngine`
- `PubspecLockAnalyzer`
- `LockfileAnalysisResult`
- `DiagnosticSource`
- `AiProvider`
- `AiRequest`
- `AiResponse`

## 6. Dependency Impact
This phase should avoid heavy new dependencies.

A reasonable addition is the `yaml` package for parsing `pubspec.yaml` and lockfile-like YAML if needed, but the package should remain lightweight and avoid AI SDKs in the core runtime.

## 7. Test Strategy
Use fixture-driven tests for:

- project detection
- `pubspec.yaml` parsing
- lockfile parsing
- build-log rules
- CLI JSON output
- report rendering
- performance calculation logic
- UI heuristics
- redaction and privacy checks

## 8. Known Limitations
- A full runtime performance profiler is not realistic in this phase without a more explicit Flutter runtime integration.
- AI must remain optional and minimal.
- The package should still be described honestly as a developer-preview tool.

## 9. Implementation Principles
- Do not add fake metrics or fake features.
- Keep the CLI usable and deterministic.
- Keep AI optional and safe.
- Preserve working code and extend it incrementally.
- Make the tool honest about uncertainty and limitations.
