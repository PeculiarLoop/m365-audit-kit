function Invoke-M365Investigation {
    <#
    .SYNOPSIS
        Performs a targeted investigation against Unified Audit Log and other sources.

    .DESCRIPTION
        Use this cmdlet to pull audit events between a start and end time
        with optional filters such as user principal names and operation
        names.  It can query both the Search‑UnifiedAuditLog cmdlet and the
        Management Activity API, performing time slicing for long
        intervals.  Results are returned in a normalized schema and may be
        exported via `Export-M365AuditReport`.

    .PARAMETER Start
        Beginning of the time window (inclusive).

    .PARAMETER End
        End of the time window (exclusive).  Defaults to now.

    .PARAMETER Users
        Array of UPNs or wildcard patterns to filter by target user.

    .PARAMETER Operations
        Array of operation names to filter.  When omitted all operations
        are returned.

    .PARAMETER Sources
        One or more sources to query.  Supported values: UAL, EntraSignIn,
        EntraAudit, EXO.  Defaults to UAL only.

    .PARAMETER OutFolder
        Path where export files should be written.

    .EXAMPLE
        Invoke-M365Investigation -Start '2025-08-01' -End '2025-08-10' -Users *@contoso.com -Operations SignIn,AddOAuthClient -Sources UAL,EntraSignIn

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [DateTime]$Start,
        [Parameter()] [DateTime]$End = (Get-Date),
        [string[]]$Users,
        [string[]]$Operations,
        [ValidateSet('UAL','EntraSignIn','EntraAudit','EXO')]
        [string[]]$Sources = @('UAL'),
        [string]$OutFolder
    )

    begin {
        if (-not $global:M365AuditKitConnected) {
            throw 'You must call Connect-M365AuditKit before running investigations.'
        }
        Write-Verbose "Performing investigation from $Start to $End for users: $($Users -join ',') and operations: $($Operations -join ',')"
    }
    process {
        $allEvents = @()
        foreach ($source in $Sources) {
            switch ($source) {
                'UAL' {
                    Write-Verbose 'Querying Unified Audit Log...'
                    $allEvents += Get-UalEvents -StartTime $Start -EndTime $End -Users $Users -Operations $Operations
                }
                'EntraSignIn' {
                    Write-Verbose 'Querying Entra sign‑ins...'
                    $allEvents += Get-EntraSignInEvents -StartTime $Start -EndTime $End -Users $Users -Operations $Operations
                }
                'EntraAudit' {
                    Write-Verbose 'Querying Entra audit events...'
                    $allEvents += Get-EntraAuditEvents -StartTime $Start -EndTime $End -Users $Users -Operations $Operations
                }
                'EXO' {
                    Write-Verbose 'Querying Exchange Online audit logs...'
                    $allEvents += Get-ExoAuditEvents -StartTime $Start -EndTime $End -Users $Users -Operations $Operations
                }
            }
        }
        if ($OutFolder) {
            if (-not (Test-Path $OutFolder)) { New-Item -ItemType Directory -Path $OutFolder -Force | Out-Null }
            Write-Verbose "Exporting investigation results to $OutFolder"
            Export-M365AuditReport -InputObject $allEvents -OutFolder $OutFolder -AsHtml -AsCsv -AsJson -AsMarkdown
        }
        return $allEvents
    }
}
