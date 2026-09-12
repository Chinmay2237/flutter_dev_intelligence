# Diagnostic Output Formats

`flutter_dev_intelligence` supports three rendering formats:

---

## 1. Terminal Output (`--format=terminal`)

Designed for humans and CI logs. It provides:
- Scannable headers and severity badges.
- Colorized ANSI output (or plain text with `--color=never`).
- ASCII tree fallbacks with `--ascii`.
- Explicit separation of Primary Root Causes vs Cascading Failures.

### Example

```text
Flutter Dev Intelligence Diagnostics
────────────────────────────────────────────────────────────
Project: my_flutter_app
Report ID: build_doctor_1726168000000000
Generated: 2026-09-12T19:00:00.000Z

Summary
  Total Findings:      2
  Primary Root Causes: 1
  Cascading Errors:    1

Primary Suspected Issues
────────────────────────────────────────────────────────────
[ERROR] Gradle Dependency Resolution Failure [GRADLE_DEPENDENCY_RESOLUTION_FAILED]
  Category:   Android & Gradle
  Confidence: HIGH
  Reason:     Gradle dependency resolution failure triggers downstream compilation task failures.

  Summary: Gradle failed to resolve Android dependencies from configured repositories.
  Likely Cause: A required Maven/Gradle dependency could not be found in configured repositories or network availability failed.

  Evidence:
    - Gradle Resolution Evidence: Could not resolve all dependencies for configuration ':app:debugCompileClasspath'.
    - Gradle Resolution Evidence: Could not find com.example.internal:core-sdk:2.1.0.

  Recommended Next Steps:
    1. Inspect the missing dependency artifact and repository URLs in android/build.gradle.
    2. Verify google(), mavenCentral(), and custom repository definitions.
    3. Check network connectivity or proxy settings for Gradle build.

Cascading / Secondary Failures
────────────────────────────────────────────────────────────
[ERROR] Gradle Task Execution Failure [GRADLE_TASK_FAILED]
  Category:   General Build Failure
  Confidence: MEDIUM
  Reason:     Cascading failure resulting from earlier prerequisite error.

  Summary: Gradle build task terminated with failure.
  Likely Cause: A Gradle build task failed as a downstream symptom of an earlier failure.

  Evidence:
    - Task Failure: Task :app:compileDebugJavaWithJavac FAILED
    - Task Failure: BUILD FAILED in 4s
```

---

## 2. JSON Output (`--format=json`)

Strictly typed machine-readable JSON schema.

### Schema Structure

```json
{
  "schemaVersion": "1.0",
  "tool": {
    "name": "flutter_dev_intelligence",
    "version": "1.0.3"
  },
  "id": "build_doctor_1726168000000000",
  "createdAt": "2026-09-12T19:00:00.000Z",
  "projectName": "my_flutter_app",
  "commandName": "build-doctor",
  "analyzerType": "BuildDoctorEngine",
  "analysisStatus": "actionable",
  "summary": {
    "total": 2,
    "primary": 1,
    "cascading": 1,
    "critical": 0,
    "error": 2,
    "warning": 0,
    "info": 0
  },
  "findings": [
    {
      "id": "GRADLE_DEPENDENCY_RESOLUTION_FAILED",
      "title": "Gradle Dependency Resolution Failure",
      "category": "androidGradle",
      "severity": "error",
      "confidence": "high",
      "summary": "Gradle failed to resolve Android dependencies from configured repositories.",
      "likelyCause": "A required Maven/Gradle dependency could not be found in configured repositories or network availability failed.",
      "evidence": [
        {
          "label": "Gradle Resolution Evidence",
          "value": "Could not resolve all dependencies for configuration ':app:debugCompileClasspath'.",
          "type": "log"
        }
      ],
      "recommendations": [
        {
          "action": "Inspect the missing dependency artifact and repository URLs in android/build.gradle.",
          "details": ""
        }
      ],
      "primaryStatus": "primary",
      "classificationReason": "Gradle dependency resolution failure triggers downstream compilation task failures.",
      "relatedFindingIds": [],
      "source": "build_doctor",
      "isPrimary": true
    }
  ]
}
```

---

## 3. Markdown Output (`--format=markdown`)

GitHub-flavored Markdown suited for pull request comments and GitHub Actions summaries.
