# Flutter Dev Intelligence CLI Command Reference

This document provides a comprehensive reference for `flutter_dev_intelligence` CLI usage.

---

## Flagship Command: `build-doctor`

The `build-doctor` command analyzes Flutter, Dart, Android/Gradle, and iOS/CocoaPods build logs to isolate failure root causes and separate cascading errors.

### Syntax

```bash
dart run flutter_dev_intelligence build-doctor [--log=<path> | --stdin] [options]
```

---

## Options & Flags

| Option | Flag Alias | Description | Default |
| :--- | :--- | :--- | :--- |
| `--log <path>` | | Path to build log file | None |
| `--stdin` | | Read build log input from standard input pipe | `false` |
| `--format <format>` | | Output report format: `terminal`, `json`, `markdown` | `terminal` |
| `--output <path>` | | Write rendered report to file path | Standard output (`stdout`) |
| `--color <mode>` | | Terminal color mode: `auto`, `always`, `never` | `auto` |
| `--no-color` | | Disable terminal ANSI colors | `false` |
| `--ascii` | | Use plain ASCII character tree formatting | `false` |
| `--project <path>` | | Path to target project root directory | Current directory (`.`) |
| `--verbose` | | Print execution trace details and stack traces | `false` |
| `--quiet` | | Suppress standard output | `false` |
| `--help` | `-h` | Display command help message | |
| `--version` | `-v` | Display package version | |

---

## Examples

### 1. Terminal Analysis of Build Log File

```bash
dart run flutter_dev_intelligence build-doctor --log=build.log
```

### 2. Pipe Build Output from Flutter CLI

```bash
flutter build apk 2>&1 | dart run flutter_dev_intelligence build-doctor --stdin
```

### 3. Machine-Readable JSON Output for CI Archiving

```bash
dart run flutter_dev_intelligence build-doctor --log=build.log --format=json --output=report.json
```

### 4. Markdown Format for GitHub Issue / PR Comments

```bash
dart run flutter_dev_intelligence build-doctor --log=build.log --format=markdown
```

---

## Exit Codes

| Exit Code | Meaning |
| :---: | :--- |
| `0` | **Success**: Log analyzed clean with 0 critical or error findings. |
| `1` | **Actionable Findings**: One or more error or critical findings were identified. |
| `2` | **Usage / Input Error**: Missing input log file, empty input, or invalid flags. |
| `3` | **System Error**: Unexpected exception during execution. |
