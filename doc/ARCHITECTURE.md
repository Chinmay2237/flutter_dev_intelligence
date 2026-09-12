# Architecture & Pipeline Design

`flutter_dev_intelligence` follows a clean, decoupled data pipeline for offline log analysis.

---

## Data Pipeline

```text
Raw Log Input (File or Stdin Stream)
    ↓
[InputLoader]
- Reads input with file size safety checks & tail-truncation limits
    ↓
[LogNormalizer]
- Strips ANSI escape codes
- Normalizes CRLF / LF line endings
- Redacts credentials, private keys, tokens, and home paths
    ↓
[LogParser]
- Extracts log events, context blocks, task failures, and compiler line errors
    ↓
[RuleMatcher]
- Evaluates diagnostic rules against log events and evidence
    ↓
[RootCauseClassifier]
- Builds causal prioritization graph to classify findings as Primary, Cascading, or Independent
    ↓
[ReportGenerator]
- Aggregates findings, summary stats, and metadata into a DiagnosticReport
    ↓
[TerminalReporter | JsonReporter | MarkdownReporter]
- Renders final output in requested format
```

---

## Core Design Principles

1. **Separation of Concerns**: Parsing contains no rendering logic; rules are decoupled from terminal output.
2. **Determinism**: Identical log inputs always produce identical diagnostic reports.
3. **No Unsafe Side Effects**: Read-only log evaluation; no global state mutation, network calls, or disk file modifications.
4. **Defensible Confidence**: Rules assign explicit confidence (`high`, `medium`, `low`, `unknown`) based on matched evidence context rather than arbitrary numerical thresholds.
