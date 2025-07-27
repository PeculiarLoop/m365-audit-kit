# First Run: Connect-M365Audit with App-Only Certificate

This guide describes how to run the `Connect-M365Audit` function for the first time using an app‑only (certificate) authentication model. Interactive delegated authentication is also covered.

## Prerequisites

- **PowerShell 7.2 or later** installed.
- **Microsoft Graph PowerShell SDK** and **ExchangeOnlineManagement** modules available. These are installed automatically in the provided CI workflow.
- An **Azure AD application** registered with permissions such as `Policy.Read.All` and `Directory.Read.All`; if you plan to connect to Exchange Online, add `Exchange.ManageAsApp`.
- A **certificate** (self‑signed or issued) uploaded to your Azure AD application. Note the certificate **thumbprint** and ensure the private key is available on the system executing the script.

> *Never commit secrets, tenant IDs, or certificate files to this repository.*

## Configuring environment

You can pass parameters directly or load them from a configuration file. See `samples/config.sample.json` for an example JSON configuration. Alternatively, set variables in your shell:

```
$tenantId  = '00000000-0000-0000-0000-000000000000'
$clientId  = '00000000-0000-0000-0000-000000000000'
$thumbprint = 'THUMBPRINTGOESHERE'
```

## App-only certificate authentication

Use the following commands to load the module and establish an app‑only session with both Microsoft Graph and Exchange Online:

```
# Import the module from the src folder
Import-Module './src/M365AuditKit' -Force

$ctx = Connect-M365Audit \
    -TenantId $tenantId \
    -ClientId  $clientId \
    -CertificateThumbprint $thumbprint \
    -ConnectExchange \
    -PassThru \
    -Verbose
```

The function returns a context object with `Graph` and `Exchange` properties for use in subsequent cmdlets. Omit `-PassThru` to set a global `$script:M365AuditContext` instead.

## Delegated interactive authentication

For interactive or delegated scenarios, you can rely on browser-based sign‑in:

```
Import-Module './src/M365AuditKit' -Force

# Optionally specify scopes; multiple scopes can be supplied in a string array
$ctx = Connect-M365Audit \
    -Scope 'Policy.Read.All','Directory.Read.All' \
    -ConnectExchange \
    -PassThru \
    -Verbose
```

When invoked without `-TenantId`, `-ClientId`, and `-CertificateThumbprint`, the function uses the delegated authentication flow and prompts you to authenticate interactively. Ensure you have the necessary privileges and MFA available.

## Next steps

Once connected, you can execute other cmdlets in the **M365AuditKit**. Most cmdlets accept the context returned by `Connect-M365Audit` via the `-Context` parameter. For example:

```
Get-M365PrivilegedRoleReport -Context $ctx -Verbose | Format-Table
```

For automation, schedule this script within Azure Automation or a CI/CD pipeline. Store your certificate securely (e.g., Azure Key Vault) and inject secrets at runtime rather than hard‑coding them.
