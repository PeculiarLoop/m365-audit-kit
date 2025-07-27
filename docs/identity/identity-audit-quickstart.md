# Identity Audit Quickstart

This quickstart demonstrates how to use the M365 Audit Kit’s identity-focused cmdlets to assess privileged roles, conditional access policies, and application consent risk in your Microsoft 365 tenant.

## Prerequisites

* **PowerShell 7.2 or later** installed. The module requires PowerShell Core and the Microsoft Graph SDK.
* **Connect-M365Audit** must be executed first to establish a connection context. See the [first run guide](../quickstarts/first-run-with-app-only-cert.md) for authentication setup.
* Appropriate Graph API permissions: `RoleManagement.Read.Directory`, `Policy.Read.All`, `AppRoleAssignment.Read.All`, and `Directory.Read.All` for app-only scenarios.

> **Note:** Never store secrets or tenant identifiers in the repository. Use a `.env` or `config.json` file outside of version control to supply credentials.

## 1. Privileged Role Report

The **Get-M365PrivilegedRoleReport** cmdlet inventories directory role assignments (PIM eligible/active and standing roles), highlights break-glass accounts, and checks MFA status of administrators.

```powershell
# Connect using a certificate or delegated auth
Connect-M365Audit -TenantId $env:TENANT_ID -ClientId $env:CLIENT_ID -CertificateThumbprint $env:CERTIFICATE_THUMBPRINT

# Generate the privileged role report and save as JSON
Get-M365PrivilegedRoleReport -OutPath ./out -Format json -Verbose
```

The generated JSON includes each role assignment with properties such as `UserPrincipalName`, `RoleName`, `AssignmentType` (Active/Eligible), and `IsMfaEnabled`. Review the output for accounts without MFA or standing Global Administrator rights.

## 2. Conditional Access Policy Report

**Get-M365ConditionalAccessReport** retrieves all conditional access policies and flags risky configurations (e.g., policies applying to all users and all apps without grant controls). Use the `-Since` parameter to limit to recent changes.

```powershell
# Export conditional access policies to Markdown and CSV
Get-M365ConditionalAccessReport -OutPath ./out -Format md,csv -Verbose
```

The Markdown output includes a table summarising each policy’s state, assignments, grant controls, and whether it is considered risky. Investigate and remediate any policy with `IsRisky = $true`.

## 3. Application Consent Risk Report

The **Get-M365AppConsentRisk** cmdlet identifies OAuth app consents with high-privilege scopes, expiring secrets or certificates, and stale service principals.

```powershell
# List high-risk app consents and output as CSV
Get-M365AppConsentRisk -OutPath ./out -Format csv -Verbose
```

Results include service principal details (AppId, DisplayName), granted scopes, expiration dates, and risk flags. Pay attention to entries with scopes like `Directory.ReadWrite.All`, or secrets expiring within 30 days.

## Next Steps

* Correlate identity findings with secure score metrics using upcoming reports (Secure Score cmdlets will be added later).
* Schedule periodic audits by incorporating these cmdlets into automation runbooks or CI pipelines.
* Contribute feedback or enhancements via pull requests.
