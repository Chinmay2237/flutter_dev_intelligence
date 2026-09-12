# Privacy & Security Policy (`flutter_dev_intelligence`)

`flutter_dev_intelligence` is engineered with a local-first, zero-network-by-default architecture to safeguard developer codebases, build artifacts, credentials, and user data.

---

## 1. Zero Network Requests by Default

- **Offline Execution**: 100% of diagnostic analyses (UI AST analysis, build log parsing, performance trace evaluation, and report generation) execute strictly within your local machine or CI environment.
- **No Telemetry / Analytics**: The package contains zero telemetry, analytics trackers, phone-home mechanisms, or automated update checks.

---

## 2. Opt-In AI Advisory & Data Minimization

- **Explicit Opt-In**: AI advisory features are completely disabled by default (`aiEnabled = false`).
- **Local Fallback**: When AI features are not enabled or when network connections are unavailable, the package falls back to deterministic local rule recommendations without throwing errors.
- **Payload Minimization**: If AI is explicitly enabled, only sanitized summary titles and evidence lines are passed to the provider. Complete source files or full build log streams are never uploaded.

---

## 3. Automatic Secret Redaction Engine

Before diagnostic reports are printed or payloads sent, text passes through the built-in `PrivacyRedactor`:

### Patterns Redacted:
1. **API Keys**:
   - OpenAI Keys (`sk-[a-zA-Z0-9]{20,}`) -> `[REDACTED_OPENAI_KEY]`
   - AWS Access Keys (`AKIA[0-9A-Z]{16}`) -> `[REDACTED_AWS_KEY]`
   - GCP API Keys (`AIzaSy[a-zA-Z0-9_-]{33}`) -> `[REDACTED_GCP_KEY]`
2. **Bearer Tokens**:
   - `Authorization: Bearer <token>` -> `Authorization: Bearer [REDACTED]`
3. **Credentials & Passwords**:
   - Credentials in URLs (`https://user:pass@host/`) -> `https://[REDACTED]@host/`
   - Key/Value password entries (`password=...`) -> `password=[REDACTED]`
4. **User Home File Paths**:
   - Linux/Mac home paths (`/home/username/...`, `/Users/username/...`) -> `~/...`

---

## 4. Security Reporting

To report a security vulnerability or secret handling issue, please follow our [SECURITY.md](../SECURITY.md) guidelines or create a confidential issue on our repository issue tracker.
