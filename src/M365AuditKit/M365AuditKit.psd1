@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'M365AuditKit.psm1'
    ModuleVersion     = '0.1.0'
    CompatiblePSEditions = @('Core')
    GUID              = '5f42edc2-70b4-4ed7-9e16-111111111111'
    Author            = 'M365 Audit Kit Contributors'
    CompanyName       = 'FQHC Security Consortium'
    Copyright         = '(c) 2025 M365 Audit Kit Contributors. All rights reserved.'
    Description       = 'Audit toolkit for Microsoft 365 posture, compliance and incident response.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @('Connect-M365Audit'),'Get-M65ForwardingAndInboxRules','Get-M365MailAuthPosture')
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'
    RequiredModules   = @('Microsoft.Graph', 'ExchangeOnlineManagement')
    PrivateData = @{ 
        PSData = @{ 
            Tags = @('PowerShell','Microsoft365','Audit','Security')
            LicenseUri = 'https://github.com/PeculiarLoop/m365-audit-kit/blob/main/LICENSE'
            ProjectUri = 'https://github.com/PeculiarLoop/m365-audit-kit'
            ReleaseNotes = 'Initial scaffold release.'
        }
    }
}
