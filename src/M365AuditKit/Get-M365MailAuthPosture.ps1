#Requires -Version 7.2
<#
.SYNOPSIS
    Generates a report on the tenant's email authentication and protection posture.
.DESCRIPTION
    This cmdlet queries Exchange Online to assess your organization's mail authentication and threat-protection configuration.
    It enumerates accepted domains and checks whether SPF, DKIM and DMARC records are present.
    It also inspects Defender for Office 365 policies—Safe Links, Safe Attachments and Anti-Phish—to determine if protection is enabled.
    Safe Links rewrites and checks URLs in email messages against a list of known malicious sites【779818019524767†L80-L86】.
    Safe Attachments detonate suspicious files in a sandbox, and anti-phishing policies provide spoof and impersonation protection.
.PARAMETER Context
    A connection context object returned from Connect‑M365Audit. If omitted, the function will use the global $M365AuditContext.
.PARAMETER OutPath
    Directory where output files will be written. If omitted, objects are returned.
.PARAMETER Format
    Output format when OutPath is specified: 'json', 'csv' or 'md'. Default 'json'.
.PARAMETER PassThru
    Return objects even when OutPath is used.
.EXAMPLE
    Get‑M365MailAuthPosture -OutPath ./out -Format md -Verbose
    Evaluates SPF, DKIM, DMARC and threat-protection policies and writes a Markdown report.
.PERMISSIONS
    ExchangeOnlineManagement: View-Only Organization Management or equivalent.
.DATA COLLECTED
    Domain names, DNS record values, and policy names/states. Does not collect email contents.
.CAVEATS
    DNS lookups require network connectivity and may fail if blocked. DKIM cmdlets require Exchange Online.
#>
function Get-M365MailAuthPosture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [object]$Context,
        [Parameter()]
        [string]$OutPath,
        [Parameter()]
        [ValidateSet('json','csv','md')]
        [string]$Format = 'json',
        [switch]$PassThru
    )

    begin {
        if (-not $PSBoundParameters.ContainsKey('Context')) {
            if ($Global:M365AuditContext) { $Context = $Global:M365AuditContext }
        }
        Write-Verbose "Using context: $($Context | Out-String)"
        $results = @()
    }

    process {
        # Accepted domains
        try {
            $accepted = Get-AcceptedDomain -ErrorAction Stop
        } catch {
            throw "Failed to retrieve accepted domains. Ensure you are connected to Exchange Online."
        }

        foreach ($domain in $accepted) {
            Write-Verbose "Processing domain $($domain.DomainName)"
            $spfRecord = $null
            $spfPresent = $false
            try {
                $txtRecords = Resolve-DnsName -Name $domain.DomainName -Type TXT -ErrorAction Stop
                $spfStrings = $txtRecords | Where-Object { $_.Strings -match '^v=spf1' } | Select-Object -ExpandProperty Strings
                if ($spfStrings) {
                    $spfPresent = $true
                    $spfRecord = ($spfStrings -join '; ')
                }
            } catch {
                Write-Verbose "No SPF record found for $($domain.DomainName)"
            }
            # DKIM
            $dkimEnabled = $false
            $dkimSelector = $null
            try {
                $dkim = Get-DkimSigningConfig -Identity $domain.DomainName -ErrorAction Stop
                if ($dkim -and $dkim.Enabled -eq $true) {
                    $dkimEnabled = $true
                    $dkimSelector = $dkim.Selector
                }
            } catch {
                Write-Verbose "No DKIM config for $($domain.DomainName)"
            }
            # DMARC
            $dmarcPresent = $false
            $dmarcRecord = $null
            try {
                $dmarcTxt = Resolve-DnsName -Name "_dmarc.$($domain.DomainName)" -Type TXT -ErrorAction Stop
                $dmarcStrings = $dmarcTxt | Select-Object -ExpandProperty Strings
                if ($dmarcStrings) {
                    $dmarcPresent = $true
                    $dmarcRecord = ($dmarcStrings -join '; ')
                }
            } catch {
                Write-Verbose "No DMARC record for $($domain.DomainName)"
            }
            $results += [pscustomobject]@{
                Type          = 'Domain'
                DomainName    = $domain.DomainName
                DomainType    = $domain.DomainType
                SPFPresent    = $spfPresent
                SPFRecord     = $spfRecord
                DKIMEnabled   = $dkimEnabled
                DKIMSelector  = $dkimSelector
                DMARCPresent  = $dmarcPresent
                DMARCRecord   = $dmarcRecord
            }
        }

        # Defender policies
        Write-Verbose "Retrieving Safe Links policies"
        $safeLinksPolicies = Get-SafeLinksPolicy -ErrorAction SilentlyContinue
        if ($safeLinksPolicies) {
            foreach ($pol in $safeLinksPolicies) {
                $results += [pscustomobject]@{
                    Type       = 'SafeLinksPolicy'
                    Name       = $pol.Name
                    Enabled    = $pol.EnableSafeLinksForEmail
                    TrackClicks= $pol.EnableURLTrace
                }
            }
        }

        Write-Verbose "Retrieving Safe Attachments policies"
        $safeAttachmentPolicies = $null
        try {
            $safeAttachmentPolicies = Get-SafeAttachmentPolicy -ErrorAction SilentlyContinue
        } catch {}
        if ($safeAttachmentPolicies) {
            foreach ($pol in $safeAttachmentPolicies) {
                $results += [pscustomobject]@{
                    Type       = 'SafeAttachmentPolicy'
                    Name       = $pol.Name
                    Enabled    = $pol.Enabled
                    Action     = $pol.Action
                }
            }
        }

        Write-Verbose "Retrieving Anti-Phish policies"
        $antiPhishPolicies = $null
        try {
            $antiPhishPolicies = Get-AntiPhishPolicy -ErrorAction SilentlyContinue
        } catch {}
        if ($antiPhishPolicies) {
            foreach ($pol in $antiPhishPolicies) {
                $results += [pscustomobject]@{
                    Type       = 'AntiPhishPolicy'
                    Name       = $pol.Name
                    Enabled    = $pol.Enabled
                    PhishThresholdLevel = $pol.PhishThresholdLevel
                }
            }
        }
    }

    end {
        if ($OutPath) {
            $resolvedOutPath = Resolve-Path -Path $OutPath -ErrorAction SilentlyContinue
            if (-not $resolvedOutPath) {
                New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
                $resolvedOutPath = Resolve-Path -Path $OutPath
            }
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            switch ($Format) {
                'json' {
                    $filePath = Join-Path $resolvedOutPath "MailAuthPosture_$timestamp.json"
                    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding utf8
                }
                'csv' {
                    $filePath = Join-Path $resolvedOutPath "MailAuthPosture_$timestamp.csv"
                    $results | Export-Csv -Path $filePath -NoTypeInformation -Force
                }
                'md' {
                    $filePath = Join-Path $resolvedOutPath "MailAuthPosture_$timestamp.md"
                    $mdLines = @()
                    $mdLines += "# Mail Authentication and Protection Posture Report"
                    $mdLines += ""
                    $mdLines += "|Type|Name/Domain|Details|"
                    $mdLines += "|---|---|---|"
                    foreach ($item in $results) {
                        switch ($item.Type) {
                            'Domain' {
                                $details = "SPF=$($item.SPFPresent); DKIM=$($item.DKIMEnabled); DMARC=$($item.DMARCPresent)"
                                $mdLines += "|Domain|$($item.DomainName)|$details|"
                            }
                            'SafeLinksPolicy' {
                                $details = "Enabled=$($item.Enabled); TrackClicks=$($item.TrackClicks)"
                                $mdLines += "|SafeLinksPolicy|$($item.Name)|$details|"
                            }
                            'SafeAttachmentPolicy' {
                                $details = "Enabled=$($item.Enabled); Action=$($item.Action)"
                                $mdLines += "|SafeAttachmentPolicy|$($item.Name)|$details|"
                            }
                            'AntiPhishPolicy' {
                                $details = "Enabled=$($item.Enabled); PhishThresholdLevel=$($item.PhishThresholdLevel)"
                                $mdLines += "|AntiPhishPolicy|$($item.Name)|$details|"
                            }
                        }
                    }
                    $mdLines | Out-File -FilePath $filePath -Encoding utf8
                }
            }
            Write-Verbose "Exported results to $filePath"
            if ($PassThru) { return $results }
        } else {
            return $results
        }
    }
}
