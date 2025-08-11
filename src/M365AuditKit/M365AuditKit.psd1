@{
    # Module manifest for virtuALLY M365 Audit Kit
    RootModule        = 'M365AuditKit.psm1'
    ModuleVersion     = '1.0.0'
    CompatiblePSEditions = @('Core')
    GUID              = '5f4822de-70b4-4ed7-9e16-111111111111'
    Author            = 'M365 Audit Kit Contributors'
    CompanyName       = 'M365 Audit Kit Contributors'
    Copyright         = '(c) 2025 M365 Audit Kit Contributors. All rights reserved.'
    Description       = 'Audit toolkit for Microsoft 365 posture, compliance and incident response.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'Connect-M365AuditKit',
        'Start-M365QuickAudit',
        'Invoke-M365Investigation',
        'Connect-M365Audit',
        'Get-M365ForwardingAndInboxRules',
        'Get-M365MailAuthPosture'
    )
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'
    RequiredModules   = @('Microsoft.Graph','ExchangeOnlineManagement')
    PrivateData       = @{
        PSData = @{
            Tags        = @('PowerShell','Microsoft365','Audit','Security')
            LicenseUri  = 'https://github.com/PeculiarLoop/m365-audit-kit/blob/main/LICENSE'
            ProjectUri  = 'https://github.com/PeculiarLoop/m365-audit-kit'
            ReleaseNotes = 'Version 1.0.0 - virtuALLY GUI and enhanced audit kit.'
        }
    }
}
