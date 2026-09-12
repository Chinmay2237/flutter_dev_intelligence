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
