## 1.2.0

### Added
- Added UI Doctor static diagnostic suite (`ui-doctor`, `inspect`, `ui` CLI commands).
- Added UI Doctor baseline generation with `--generate-baseline`.
- Added baseline comparison with `--baseline`.
- Added detection of `new`, `resolved`, and `unchanged` findings.
- Added `--fail-on-new` for CI quality gates.
- Added `.flutter_dev_intelligence.yaml` support for UI Doctor configuration.
- Added configurable rule thresholds, severity overrides, disabled rules, and path exclusions.
- Added miniature Flutter fixture project and integration coverage.

### Improved
- Reduced false positives for production debug logging (respecting `kDebugMode` condition guards).
- Ignored `test/`, `integration_test/`, `tool/`, `bin/`, and generated code paths (`*.g.dart`, `*.freezed.dart`) by default.
- Improved handling of decorative images using `excludeFromSemantics` and `ExcludeSemantics`.
- Refined performance and maintainability guidance to describe static heuristics accurately.
- Improved terminal reporting for baseline and diff results.

### Validation
- `dart analyze` passes with zero issues.
- All automated unit and integration tests pass.

## 1.0.4

- **Offline-First Diagnostic Intelligence Transformation**: Transformed package into a deterministic, evidence-based diagnostic analyzer focused on Flutter and Dart build log analysis.
- **Primary Root-Cause Prioritization**: Introduced causal graph prioritization that distinguishes primary failure root causes from downstream cascading symptoms (such as `BUILD FAILED` or task execution errors).
- **Evidence & Defensible Confidence**: Added structured evidence references, context lines, and explicit confidence levels (`high`, `medium`, `low`, `unknown`) to all diagnostic findings.
- **Dependency Reduction**: Removed heavy `analyzer` AST package dependency, significantly improving pub resolution time and package compile speed.
- **Scope Streamlining**: Removed experimental/out-of-scope modules (`ui_doctor`, `performance`, `auto_fix_engine`, `ai_provider`) to focus 100% on build log diagnostic accuracy and local-first execution.
- **Multi-Format Exporters**: Refactored Terminal, JSON, and Markdown reporters for clean CI and terminal reporting.

## 1.0.3

- **CLI UX & Documentation Overhaul**: Updated CLI help output, missing-input messages, and error handling for user-friendly execution without raw stack traces.
- **Documentation Overhaul**: Completely rewritten `README.md` focusing strictly on CLI terminal usage and global activation.
- **Comprehensive Reference Guides**: Added detailed documentation files under `doc/`.
