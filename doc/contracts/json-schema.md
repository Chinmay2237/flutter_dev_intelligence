# JSON Schema & Machine Output Contract — `flutter_dev_intelligence` 1.0.0

This document defines the stable, versioned JSON contract emitted by `flutter_dev_intelligence` CLI commands (`--format json`) and programmatically via `DiagnosticReport.toJson()`.

---

## 1. Contract Overview & Versioning

- **Current Schema Version:** `"1.0"`
- **Stability Policy:** All major versions (`1.x.x`) guarantee non-breaking additions. Fields will not be removed or renamed without a major version bump (`2.0.0`) and a minimum 6-month deprecation period.
- **Formal Schema File:** [diagnostic_report.schema.json](file:///home/chinmay/Projects/flutter_dev_intelligence/docs/contracts/diagnostic_report.schema.json)

---

## 2. Top-Level Structure

```json
{
  "schemaVersion": "1.0",
  "tool": {
    "name": "flutter_dev_intelligence",
    "version": "1.0.0"
  },
  "analysis": {
    "engine": "ui-doctor",
    "status": "completed",
    "durationMs": 184,
    "filesAnalyzed": 42,
    "rulesExecuted": 28
  },
  "summary": {
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 3,
    "info": 4,
    "actionable": 3,
    "total": 10
  },
  "id": "ui_doctor_1740000000000",
  "createdAt": "2026-09-12T12:00:00.000Z",
  "projectName": "my_flutter_app",
  "projectPath": "/path/to/my_flutter_app",
  "issues": [],
  "metrics": {},
  "warnings": [],
  "limitations": [],
  "skippedAnalyses": [],
  "unavailableAnalyses": []
}
```

---

## 3. Section Reference

### 3.1 `tool` Object

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | `string` | Package binary name (`flutter_dev_intelligence`). |
| `version` | `string` | Installed package semantic version string (`1.0.0`). |

### 3.2 `analysis` Object

| Field | Type | Description |
| :--- | :--- | :--- |
| `engine` | `string?` | Specific engine executed (`doctor`, `build-doctor`, `ui-doctor`, `performance`). |
| `status` | `string` | Execution status: `completed`, `actionable`, `partial`, `failed`, `unknown`. |
| `durationMs` | `integer?` | Total execution wall time in milliseconds. |
| `filesAnalyzed` | `integer?` | Total number of Dart source or log files scanned. |
| `rulesExecuted` | `integer?` | Number of diagnostic rule evaluators invoked. |

### 3.3 `summary` Object

| Field | Type | Description |
| :--- | :--- | :--- |
| `critical` | `integer` | Count of `critical` severity issues. |
| `high` | `integer` | Count of `high` severity issues. |
| `medium` | `integer` | Count of `medium` severity issues. |
| `low` | `integer` | Count of `low` severity issues. |
| `info` | `integer` | Count of `info` severity issues. |
| `actionable` | `integer` | Sum of `critical` + `high` + `medium` issues requiring intervention. |
| `total` | `integer` | Total issue count. |

---

## 4. Diagnostic Issue Schema (`issues[]`)

Each item in the `issues` list contains:

```json
{
  "id": "ui.nested-scrollable",
  "category": "layout",
  "severity": "high",
  "title": "Nested scrollables with shrinkWrap detected",
  "description": "ListView contains a child GridView with shrinkWrap enabled.",
  "filePath": "lib/widgets/my_list.dart",
  "line": 42,
  "confidence": 0.90,
  "source": "static AST analysis",
  "evidence": [
    {
      "type": "sourceFile",
      "label": "parent",
      "value": "ListView"
    }
  ],
  "suggestions": [
    {
      "action": "Replace inner GridView with SliverGrid inside CustomScrollView.",
      "details": "Using Slivers eliminates shrinkWrap calculation overhead.",
      "riskLevel": "low",
      "isSafeToAutomate": false,
      "requiresUserConfirmation": true
    }
  ]
}
```

---

## 5. Enum Contracts

### `DiagnosticSeverity`
- `critical`: High likelihood of app crash or build failure.
- `high`: Severe UI jank, memory leak, or layout breakage.
- `medium`: Suboptimal pattern or performance degradation.
- `low`: Minor code smell or style suggestion.
- `info`: Informational observation (never treated as failure).

### `DiagnosticCategory`
`build`, `dependency`, `gradle`, `kotlin`, `java`, `ios`, `xcode`, `cocoapods`, `layout`, `responsive`, `accessibility`, `localization`, `visual`, `performance`, `startup`, `frame`, `rebuild`, `network`, `memory`, `architecture`.

---

## 6. Exit Codes & CI Integration

- **`0`**: Execution succeeded and `summary.actionable` is `0`.
- **`1`**: `summary.actionable > 0` (high or critical issues detected).
- **`2`**: Command argument, path, or configuration validation failure.
- **`3`**: Exception or execution crash.
