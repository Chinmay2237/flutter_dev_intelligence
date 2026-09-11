# Phase 5 Implementation Plan

Phase 5 advances the verified Phase 4 developer preview toward a production candidate without replacing the working CLI, report model, build rules, or runtime instrumentation.

## Architecture Baseline

- `DoctorRunner` orchestrates project, pubspec, lockfile, and optional build-log evidence.
- `DiagnosticIssue` and `DiagnosticReport` are the shared evidence/report contracts.
- `DiagnosticReportRenderer` provides terminal, JSON, and Markdown output.
- `UiDoctor` currently provides a runtime viewport heuristic only.
- `PubspecLockAnalyzer` uses a lightweight line parser without full package metadata.
- `BuildLogParser` is deterministic but still contains inline rules.
- `FrameTimingCollector` uses real `SchedulerBinding` callbacks with bounded samples, without engine-backed integration coverage.
- `AiProvider` is an optional boundary only; there is no built-in provider or network behavior.

## Workstreams

| Workstream | Current State | Target State | Implementation Approach | Tests | Priority |
| --- | --- | --- | --- | --- | --- |
| Static UI analysis | Runtime viewport heuristic only; no AST analysis | High-confidence source diagnostics with locations and explicit static/heuristic labels | Add isolated `UiAstAnalyzer` and choose a supported analyzer integration after SDK compatibility validation. | Valid, nested-scrollable, constrained-scrollable, Expanded misuse, large-dimension, false-positive fixtures | P0 |
| Lockfile analysis | Custom line parser counts sources and name mismatches | Accurate source/version/dependency metadata where supported, with explicit malformed states | Add parser abstraction; use YAML dependency only if compatible, otherwise harden the current parser with strict limitations. | Hosted/git/path/SDK, comments, quoted values, nested sources, malformed, empty, missing, mismatch | P0 |
| Build Doctor registry | Inline string checks in `BuildLogParser` | Modular stable rule registry with positive/negative matching and deduplication | Extract rules while preserving IDs and report contracts. | Platform fixtures, ANSI, multiline, duplicates, false positives | P1 |
| Performance insights | Real frame collector with averages, worst frame, slow count | Percentiles, thresholds, evidence-backed recommendations, measured/derived/unavailable states | Add pure aggregation helpers; keep frame callbacks bounded and lightweight. | p50/p90/p99, thresholds, bounded storage, lifecycle, empty data | P1 |
| AI boundary | Typed interface only | Explicit opt-in service boundary with redaction and validation | Add policy/configuration types without network dependency or built-in provider. | Redaction, opt-in gating, malformed response, provider failure | P2 |
| Suggestions | Descriptive action/details strings | Risk-aware advisory suggestions with automation metadata | Extend `FixSuggestion` compatibly; no automatic edits by default. | Serialization and no-write safety tests | P1 |
| Reporting/schema | Stable report fields and renderers | Versioned schema and deterministic grouping by severity/source | Add backward-compatible schema metadata and grouping helpers. | JSON schema, empty reports, renderer alignment | P1 |
| CLI | Doctor/build-doctor with formats, output, quiet/verbose/no-ai, exit codes | Stable command-specific help and only implemented commands | Preserve existing commands and expose new analysis only after orchestration exists. | Process tests for supported flags and errors | P1 |
| Privacy | Common secret redaction; local-only default | Centralized redaction before report export or future AI payloads | Add configurable path/private URL normalization; no default network behavior. | Credentials, paths, URLs, report payloads | P1 |
| Example/docs | Minimal API example without platform runners | Clear API demonstration and feature labels | Clarify API-demo intent and document stable, experimental, heuristic, runtime-only, optional, unavailable states. | Example analysis/tests and documentation checks | P2 |
| CI/release | Local validation only | Reproducible format/analyze/test/publish-dry-run automation | Add CI after local commands and supported SDKs are stable. | Workflow command parity and publish dry-run | P2 |

## Implementation Order

1. Validate analyzer dependency compatibility and implement the isolated static UI analysis boundary, or document a compatibility blocker without a regex fallback.
2. Harden lockfile parsing with realistic fixtures and explicit malformed-input behavior.
3. Extract modular Build Doctor rules and add negative fixtures.
4. Add pure performance aggregation and percentile tests while preserving frame lifecycle behavior.
5. Strengthen privacy/redaction, optional AI policy, suggestions, and report schema compatibly.
6. Update the example, README, CHANGELOG, and CI only for implemented behavior.
7. Run the Phase 4 verification matrix and produce `PHASE_5_IMPLEMENTATION_REPORT.md`.

## Guardrails

- Do not present regex matching as Dart AST analysis.
- Do not fabricate runtime metrics or recommendations.
- Do not require AI or make network calls by default.
- Do not modify project files automatically without explicit opt-in, diff/backup behavior, and tests.
- Preserve Phase 4 public JSON fields, CLI commands, and exit codes where practical.
- Every new diagnostic needs a stable rule ID, evidence, confidence, source classification, and focused fixture/test.
- Do not classify the package as a production candidate without source, test, CLI, example, and publish evidence.
