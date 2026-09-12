# Security & Privacy Policy

## Local-First & Privacy Commitments

`flutter_dev_intelligence` is designed as a local-first developer utility.

- **Local Execution:** All diagnostic scanners (`doctor`, `ui-doctor`, `build-doctor`, `performance`) operate strictly on local disk files and standard input streams.
- **No Unsolicited Telemetry:** The CLI tool collects no telemetry, tracking metrics, or usage data.
- **No Unsolicited Network Requests:** No network requests occur unless optional AI provider enrichment is explicitly enabled programmatically.

## Secret Redaction

The package includes `SecretRedactor` to sanitize sensitive data (API keys, IP addresses, authentication tokens, file paths) before any output is passed to external components.

## Reporting a Security Concern

If you discover a security vulnerability or sensitive data handling issue, please report it privately rather than filing a public issue.

Email the maintainers or open a private GitHub security advisory at:
`https://github.com/Chinmay2237/flutter_dev_intelligence/security/advisories`

We appreciate your responsible disclosure!
