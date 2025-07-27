# M365 Audit Kit

A modular PowerShell toolkit for auditing Microsoft 365 (M365) environments focusing on security posture, compliance evidence, and proactive incident response for healthcare providers.  

**Key Features**

- App-only (certificate) and delegated authentication via the Microsoft Graph PowerShell SDK and Exchange Online modules.
- Idempotent cmdlets with support for structured output (objects) and export formats (`json`,`csv`,`md`).
- Comprehensive audit coverage including privileged access, conditional access, OAuth consent, sign-in anomalies, external forwarding rules, mail authentication posture, external sharing settings, Teams guest access, Defender alerts, Secure Score, and unified audit log search.
- Built-in rules engine and control mappings aligned to HIPAA §164, NIST CSF 1.1/2.0, and CIS v8.
- Cross-platform support (Windows, macOS, Linux) using PowerShell 7.2+.

See the [docs](docs/) directory for usage examples, control mapping, and developer guidance.
