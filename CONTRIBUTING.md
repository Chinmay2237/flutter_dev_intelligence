# Contributing to Flutter Dev Intelligence

Thank you for your interest in contributing to `flutter_dev_intelligence`! This document provides instructions for setting up your environment, running tests, adding diagnostic rules, and submitting changes.

---

## Development Setup

### Requirements

- Dart SDK `>=3.11.5`
- Flutter SDK `>=1.17.0`

### 1. Clone the Repository

```bash
git clone https://github.com/Chinmay2237/flutter_dev_intelligence.git
cd flutter_dev_intelligence
```

### 2. Install Dependencies

```bash
flutter pub get
cd example && flutter pub get && cd ..
```

---

## Code Quality Standards & Commands

Before submitting a pull request, run all verification steps locally:

### 1. Code Formatting

Enforce standard Dart formatting:

```bash
dart format --output=none --set-exit-if-changed .
```

To auto-format code:

```bash
dart format .
```

### 2. Static Analysis

Ensure zero static analysis warnings or lints:

```bash
flutter analyze
```

### 3. Automated Unit & Integration Tests

Run package unit and integration tests:

```bash
flutter test
```

### 4. Example Application Tests

Run example project tests:

```bash
flutter test example
```

### 5. Package Validation

Validate pub.dev publishing rules:

```bash
dart pub publish --dry-run
```

---

## Git Workflow & Conventions

### Branch Naming Convention

All feature development, bug fixes, refactoring, and release preparation must be performed in dedicated branches following this pattern:

- **Features:** `feature/<short-description>` (e.g. `feature/ui-doctor`, `feature/accessibility-rules`)
- **Bug Fixes:** `fix/<short-description>` (e.g. `fix/asset-case-mismatch`, `fix/gradle-parser`)
- **Refactoring:** `refactor/<short-description>` (e.g. `refactor/diagnostic-engine`)
- **Documentation:** `docs/<short-description>` (e.g. `docs/cli-reference`)
- **Performance:** `perf/<short-description>` (e.g. `perf/source-analysis`)
- **CI / Build:** `ci/<short-description>` or `build/<short-description>`
- **Releases:** `release/<version>` (e.g. `release/1.3.0`)
- **Hotfixes:** `hotfix/<short-description>` (e.g. `hotfix/1.2.2`)

### Conventional Commit Messages

All commit messages should follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```text
<type>(<optional-scope>): <imperative description>
```

**Allowed Types:** `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Examples:**
- `feat(ui-doctor): add image semantics detection`
- `fix(build-doctor): prioritize root compiler errors`
- `docs(readme): clarify UI Doctor CLI flags`
- `refactor(reporting): simplify markdown renderer`
- `test(reporting): cover terminal report output`
- `chore(release): prepare 1.3.0`

---

## Architecture Guidelines

- **Deterministic Core:** Analyzers must yield reproducible findings for identical inputs.
- **Rule Decoupling:** Keep diagnostic rules decoupled from terminal rendering logic.
- **ANSI Code Isolation:** Domain models (`DiagnosticIssue`, `DiagnosticReport`) must store raw strings without embedded ANSI escape sequences. Renderers (`DiagnosticReportRenderer`) apply ANSI styling strictly for terminal targets.
- **Severity Levels:**
  - `HIGH` / `CRITICAL`: Severe bug, crash, or build failure risk.
  - `MEDIUM`: Meaningful risk, performance issue, or maintainability concern.
  - `LOW`: Minor code quality risk.
  - `INFO`: Advisory pattern or clean status (e.g. valid horizontal carousel in vertical list).

---

## License

By contributing to `flutter_dev_intelligence`, you agree that your contributions will be licensed under the package's [MIT License](LICENSE).

