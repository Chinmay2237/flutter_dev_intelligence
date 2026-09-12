# Privacy, Security, & Secret Redaction Policy — `flutter_dev_intelligence` 1.0.0

This document outlines the privacy design, secret redaction, path traversal boundaries, AI opt-in policy, and automated fix safety guardrails in `flutter_dev_intelligence`.

---

## 1. Local-First Privacy Defaults

- **Zero Network Requests by Default:** The package operates entirely locally on your workstation or CI runner. No network connections, phone-home telemetry, or background usage tracking occur during normal execution.
- **AI Opt-In Policy:** AI provider enrichment is strictly disabled by default (`--no-ai`). External LLM API calls are executed only when explicitly configured by the user via configuration (`ai_enabled: true`) or command-line flags.
- **Data Minimization:** No raw source files or build logs are uploaded or transmitted off-device unless explicit AI analysis is triggered by the user.

---

## 2. Automatic Secret Redaction Pipeline

Before diagnostic reports are printed, written to disk, or transmitted to an opt-in AI provider, all string contents pass through the `SecretRedactor` pipeline.

### Redacted Patterns & Tokens

| Category | Masked Pattern Example | Mask Replacement |
| :--- | :--- | :--- |
| **Private Keys** | `-----BEGIN RSA PRIVATE KEY-----` | `[REDACTED_PRIVATE_KEY]` |
| **JWT Tokens** | `eyJhbGciOiJIUzI1Ni...` | `[REDACTED_JWT_TOKEN]` |
| **Bearer Headers** | `Authorization: Bearer <token>` | `Authorization: Bearer [REDACTED]` |
| **GitHub Access Tokens** | `ghp_12345...`, `github_pat_123...` | `[REDACTED_GITHUB_TOKEN]` |
| **GitLab Tokens** | `glpat-abcdef123...` | `[REDACTED_GITLAB_TOKEN]` |
| **AWS Access Keys** | `AKIAIOSFODNN7EXAMPLE` | `[REDACTED_AWS_KEY]` |
| **GCP API Keys** | `AIzaSyA12345...` | `[REDACTED_GCP_KEY]` |
| **OpenAI Keys** | `sk-proj-12345...` | `[REDACTED_OPENAI_KEY]` |
| **URL Credentials** | `https://user:password@domain.com` | `https://[REDACTED]@domain.com` |
| **Android Keystores** | `storePassword=...`, `keyPassword=...` | `storePassword=[REDACTED]` |
| **User Path Normalization** | `/home/username/project` | `~/project` |

### Redaction Limitations
*Notice: `SecretRedactor` employs heuristic pattern matching. Custom obfuscated secrets, non-standard key names, or novel token formats might not be recognized automatically. Sensitive environments should ensure secret values are managed via secret vaults or environment variables.*

---

## 3. Safe File Handling & Path Traversal Safeguards

- **Path Canonicalization:** All file paths passed to `DoctorRunner`, `UiAstAnalyzer`, or `AutoFixEngine` are resolved using absolute path canonicalization to verify they reside within the project root directory.
- **Path Traversal Refusal:** Paths containing `..`, `/../`, or pointing outside the project boundaries are rejected with an explicit validation error.
- **Protected File Types:** The tool explicitly refuses to read or mutate:
  - Private credential files (`.env`, `credentials.json`, `service-account.json`)
  - Key material (`*.pem`, `*.jks`, `*.keystore`, `*.p12`, `id_rsa`)
  - Source control metadata (`.git/`)
  - Package lockfiles (`pubspec.lock`)
  - Generated code files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`)

---

## 4. Auto-Fix Safety Policy & AST Syntax Validation

- **Preview & Dry-Run Mode:** `AutoFixEngine.planFixes` calculates patch diff previews without writing any changes to disk.
- **Opt-In Execution:** Fixes are only applied when `--fix` / `applyFixes()` is explicitly invoked by the developer.
- **Safe vs Unsafe Classification:** Fixes flagged with `requiresUserConfirmation: true` or `isSafeToAutomate: false` are skipped automatically.
- **AST Syntax Validation Guardrail:** Before committing changes to any `.dart` file, `AutoFixEngine` compiles the proposed content in memory using `AstParser`. If the proposed change produces Dart syntax errors, the fix is immediately aborted, original file content is preserved, and the error is reported.
