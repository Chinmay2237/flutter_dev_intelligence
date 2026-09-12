# CLI Guide (`flutter_dev_intelligence`)

The `flutter_dev_intelligence` command-line tool provides developer diagnostics for Flutter project health, AST UI quality, build logs, and runtime performance.

---

## Global Command Structure

```bash
dart run flutter_dev_intelligence <command> [options]
```

Or when activated globally:

```bash
flutter_dev_intelligence <command> [options]
```

(Note: `flutter-dev` is also available as an executable alias for backward compatibility.)

---

## Commands & Aliases

### 1. `doctor` (Alias: `doc`)
Runs comprehensive health checks over the project directory, `pubspec.yaml`, `pubspec.lock`, static UI AST analysis, and optional build log files.

```bash
dart run flutter_dev_intelligence doctor --project=. --log=build.log
```

#### Options:
- `--project=<path>`: Path to Flutter project root directory (default: `.`).
- `--log=<path>`: Optional build log file to analyze.
- `--config=<path>`: Custom path to `flutter_dev_intelligence.yaml`.

---

### 2. `ui-doctor` (Alias: `ui`)
Performs static AST analysis on Dart source files below `lib/`.

```bash
flutter-dev ui-doctor --project=. --severity=medium --format=json
```

#### Options:
- `--project=<path>`: Path to Flutter project directory (default: `.`).
- `--file=<path>`: Analyze a single `.dart` file instead of entire directory.
- `--severity=<info|low|medium|high|critical>`: Minimum severity threshold.
- `--confidence=<0.0..1.0>`: Minimum confidence score filter (default: `0.0`).

---

### 3. `build-doctor` (Alias: `build`)
Parses Android, iOS, Gradle, Xcode, or CI build log text and matches root-cause rules.

```bash
flutter-dev build-doctor --log=android_build.log --format=markdown
```

#### Options:
- `--log=<path>`: Required path to build log file (or pass log content via stdin).

---

### 4. `perf-investigator` (Alias: `perf`)
Evaluates DevTools Chrome traces (`traceEvents`), frame arrays, or summarized timing JSON.

```bash
flutter-dev perf-investigator --trace=devtools_trace.json --refresh-rate=120
```

#### Options:
- `--trace=<path>`: Path to trace JSON file.
- `--refresh-rate=<hz>`: Target hardware refresh rate in Hz (default: `60.0`).

---

## Global Options

- `--format=<terminal|json|markdown>`: Output format (default: `terminal`).
- `--color=<auto|always|never>`: ANSI color mode.
- `--quiet`: Suppress non-essential progress output.
- `--verbose`: Enable detailed timing and execution metrics.
- `--ai`: Enable opt-in AI advisory explanations.
- `--help`, `-h`: Print command summary and exit `0`.
- `--version`: Print package version and exit `0`.

---

## Output Formats & ANSI Color Modes

- **Terminal (`--format=terminal`)**: Formatted human-readable report with color highlights (`auto` enables color when outputting to a TTY; respects `NO_COLOR` environment variable).
- **JSON (`--format=json`)**: Versioned `1.0` JSON report contract suitable for machine consumption and tooling integration.
- **Markdown (`--format=markdown`)**: Clean GitHub Flavored Markdown report suitable for CI job summaries.

---

## Exit Codes

- `0`: Analysis completed successfully with zero High or Critical severity issues.
- `1`: High or Critical severity diagnostic issues detected, or command argument error occurred.

---

## CI / CD Integration Examples

### GitHub Actions Workflow

```yaml
name: Flutter Dev Intelligence Check
on: [push, pull_request]

jobs:
  diagnose:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - name: Activate CLI
        run: dart pub global activate flutter_dev_intelligence
      - name: Run UI Doctor
        run: flutter_dev_intelligence ui-doctor --project=. --format=terminal --severity=high
```

---

## Error Handling & Diagnostics

If a malformed file or unexpected parse error is encountered:
- The CLI isolates the error to the specific file or rule.
- Remaining files and rules continue execution.
- Diagnostics errors are reported safely in the analysis metadata without crashing the process.
