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
