# MX365 Audit Kit

A modular PowerShell toolkit for auditing Microsoft 365 (M365) environments focusing on security posture, compliance evidence, and proactive incident response for healthcare providers.  

**Key Features**

- App-only (certificate) and delegated authentication via the Microsoft Graph PowerShell SDK and Exchange Online modules.
- Idempotent cmdlets with support for structured output (objects) and export formats (`json`,`csv`,`md`).
- Comprehensive audit coverage including privileged access, conditional access, OAuth consent, sign-in anomalies, external forwarding rules, mail authentication posture, external sharing settings, Teams guest access, Defender alerts, Secure Score, and unified audit log search.
- Built-in rules engine and control mappings aligned to HIPAA §164, NIST CSF 1.1/2.0, and CIS v8.
- Cross-platform support (Windows, macOS, Linux) using PowerShell 7.2+.

See the [docs](docs/) directory for usage examples, control mapping, and developer guidan
## Getting Started

### Prerequisites

- PowerShell 7.2 or later.
- Optional: Microsoft Graph PowerShell SDK v2 and Exchange Online modules when using advanced audit surfaces.
- Windows is required for the GUI; the command-line module works cross-platform (Windows, macOS, Linux).
- ### Downloading the toolkit

You can obtain the audit kit by cloning the repository:

```powershell
git clone https://github.com/PeculiarLoop/m365-audit-kit.git
cd m365-audit-kit
```

Alternatively you can download the zip from the Releases page and extract it.

### Importing the module and authentication

The module is cross-platform and requires PowerShell 7.2 or later. Import the manifest file, then authenticate using either delegated or app-only flows.

```powershell
# Import the module from the repo root (adjust path as needed)
Import-Module .\src\M365AuditKit\M365AuditKit.psd1 -Force

# Delegated (interactive) auth: prompts for browser-based sign in and uses Graph delegated scopes
Connect-M365AuditKit -Delegated

# App-only auth: uses a certificate for unattended scenarios.
# Provide either a certificate path and thumbprint or a certificate object.
Connect-M365AuditKit -AppId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' \
    -TenantId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' \
    -CertificatePath 'path\to\cert.pfx' -CertificatePassword (Read-Host -AsSecureString)
```

The module automatically loads required dependencies (Microsoft Graph SDK v2 and Exchange Online modules) if available. Ensure the account you authenticate with has the necessary roles (e.g., Global Reader, Compliance Administrator) or that the app registration has sufficient API permissions for the desired audit surfaces.

### Running a Quick Audit

Use `Start-M365QuickAudit` to run a one‑click audit across different profiles. The `-Profile` parameter selects the audit surface and `-DaysBack` defines the look‑back window. An output folder can be specified for reports.

```powershell
# Run a posture audit covering conditional access, mail flow, sharing, and threat surfaces
Start-M365QuickAudit -Profile Posture -DaysBack 7 -OutFolder .\out

# Other profiles available:
# Identity      – privileged roles, PIM usage, MFA gaps, legacy protocols
# Mail          – forwarding rules, auth posture, DKIM/SPF/DMARC
# Collab        – SharePoint/OneDrive/Teams sharing settings
# Threat        – Defender alert correlation and threat indicators
# Posture       – Secure Score tracking and aggregated posture
```

The cmdlet returns objects to the pipeline and writes CSV, JSON, and Markdown reports. A prettified HTML report is generated in the output folder (`report.html`). Open it in a browser to explore the findings with interactive sorting and filtering.

### Performing an Investigation

`Invoke-M365Investigation` lets you perform a targeted, time‑bounded investigation. You can specify a time range, specific users or tenants, operations to search, and which sources to query (Unified Audit Log, Entra sign‑ins, Exchange mailbox auditing, etc.).

```powershell
# Investigate sign-in anomalies and new OAuth client creations between 1 Aug and 10 Aug 2025
Invoke-M365Investigation -Start '2025-08-01' -End '2025-08-10' \
    -Users *@contoso.com \
    -Operations SignIn,AddOAuthClient \
    -Sources UAL,EntraSignIn \
    -OutFolder .\out\investigation

# The cmdlet writes structured results and creates reports in the specified folder.
```

Advanced parameters allow you to control degree of parallelism, anonymise identities (`-Anonymize`), and choose the audit pipeline (Search-UnifiedAuditLog vs Management Activity API).

### Launching the GUI (Windows)

The toolkit includes an optional Windows‑only GUI named **virtuALLY**. To launch the graphical interface, run the bootstrap script from the `gui` folder.

```powershell
# Run from the repo root or specify the full path
.\gui\virtuALLY.Gui.ps1
```

The GUI provides tabs for connecting to your tenant, running quick audits, performing investigations, browsing findings in a sortable grid, exporting reports (CSV/JSON/HTML/KQL), and scheduling recurring audits via Windows Task Scheduler.

### Example Workflow

1. Install PowerShell 7.2+ and optional dependencies (Graph and Exchange modules).
2. Clone or download the `m365-audit-kit` repository and import the module.
3. Connect to your M365 tenant using `Connect‑M365AuditKit -Delegated` or app‑only parameters.
4. Run a quick audit: `Start‑M365QuickAudit -Profile Posture -DaysBack 14 -OutFolder .\out\PostureAudit`.
5. Review `.\out\PostureAudit\report.html` for interactive findings.
6. Perform a targeted investigation with `Invoke‑M365Investigation` as needed.
7. Launch the GUI on Windows for a rich, interactive experience: `.\gui\virtuALLY.Gui.ps1`.

For more detailed usage examples, refer to the documentation in the `docs/` folder and the sample scripts provided in the `samples/` directory.


.
