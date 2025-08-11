<#
    AuditService.ps1

    Provides simple wrapper functions for the GUI to call the underlying
    module cmdlets.  This keeps the ViewModel free of direct module
    references and simplifies testing.
#>

function Run-QuickAudit {
    param(
        [Parameter(Mandatory)][string]$Profile,
        [int]$DaysBack = 7,
        [string]$OutFolder
    )
    if (-not (Get-Command -Name Start-M365QuickAudit -ErrorAction SilentlyContinue)) {
        throw 'Start-M365QuickAudit command not found.  Ensure the module is imported.'
    }
    return Start-M365QuickAudit -Profile $Profile -DaysBack $DaysBack -OutFolder $OutFolder -Verbose:$false
}

function Run-Investigation {
    param(
        [Parameter(Mandatory)][DateTime]$Start,
        [Parameter(Mandatory)][DateTime]$End,
        [string[]]$Users,
        [string[]]$Operations,
        [string[]]$Sources,
        [string]$OutFolder
    )
    if (-not (Get-Command -Name Invoke-M365Investigation -ErrorAction SilentlyContinue)) {
        throw 'Invoke-M365Investigation command not found.  Ensure the module is imported.'
    }
    return Invoke-M365Investigation -Start $Start -End $End -Users $Users -Operations $Operations -Sources $Sources -OutFolder $OutFolder -Verbose:$false
}
