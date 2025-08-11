function Start-M365QuickAudit {
    <#
    .SYNOPSIS
        Performs a one‑click quick audit against a specified M365 profile.

    .DESCRIPTION
        This cmdlet orchestrates a set of audit checks for a given profile
        (Identity, Mail, Collab, Threat or Posture) over a recent time
        window.  It invokes helper functions defined in the private module
        which return objects following a standard schema.  Those results
        can be exported to multiple formats via `Export-M365AuditReport` and
        returned to the pipeline for further processing.

    .PARAMETER Profile
        The audit profile to run.  Supported values: Identity, Mail,
        Collab, Threat, Posture.

    .PARAMETER DaysBack
        How many days of data to include in time‑bound queries (e.g.
        unified audit log).  Defaults to 7.

    .PARAMETER OutFolder
        Path where export files should be written.  When omitted no files
        are written.

    .EXAMPLE
        Start-M365QuickAudit -Profile Posture -DaysBack 7 -OutFolder ./out

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Identity','Mail','Collab','Threat','Posture')]
        [string]$Profile,

        [int]$DaysBack = 7,

        [string]$OutFolder
    )

    begin {
        if (-not $global:M365AuditKitConnected) {
            throw 'You must call Connect-M365AuditKit before running audits.'
        }
        # Calculate time window
        $endTime   = Get-Date
        $startTime = $endTime.AddDays(-[Math]::Abs($DaysBack))
        Write-Verbose "Running quick audit for profile $Profile from $($startTime.ToString()) to $($endTime.ToString())"
    }
    process {
        $results = @()
        switch ($Profile) {
            'Identity' {
                Write-Verbose 'Invoking identity & access checks...'
                $results += Invoke-IdentityAudit -StartTime $startTime -EndTime $endTime
            }
            'Mail' {
                Write-Verbose 'Invoking mail/Exchange audits...'
                $results += Invoke-MailAudit -StartTime $startTime -EndTime $endTime
            }
            'Collab' {
                Write-Verbose 'Invoking SharePoint/OneDrive/Teams audits...'
                $results += Invoke-CollabAudit -StartTime $startTime -EndTime $endTime
            }
            'Threat' {
                Write-Verbose 'Invoking Defender & threat audits...'
                $results += Invoke-ThreatAudit -StartTime $startTime -EndTime $endTime
            }
            'Posture' {
                Write-Verbose 'Invoking full posture audit across all surfaces...'
                $results += Invoke-IdentityAudit -StartTime $startTime -EndTime $endTime
                $results += Invoke-MailAudit    -StartTime $startTime -EndTime $endTime
                $results += Invoke-CollabAudit  -StartTime $startTime -EndTime $endTime
                $results += Invoke-ThreatAudit  -StartTime $startTime -EndTime $endTime
            }
        }

        # Export results if an output folder is provided
        if ($OutFolder) {
            if (-not (Test-Path $OutFolder)) { New-Item -ItemType Directory -Path $OutFolder -Force | Out-Null }
            Write-Verbose "Exporting audit results to $OutFolder"
            Export-M365AuditReport -InputObject $results -OutFolder $OutFolder -AsHtml -AsCsv -AsJson -AsMarkdown
        }
        return $results
    }
}
