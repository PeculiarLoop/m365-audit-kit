<#
    .SYNOPSIS
        Generates a report of OAuth application consents and highlights risky apps and expiring secrets.
    .DESCRIPTION
        Queries Microsoft Graph to retrieve service principals and OAuth permission grants. The report
        summarizes app ownership, high-privilege delegated and application scopes, impending secret
        expiration (within 30/60/90 days), and flags stale service principals. This helps identify
        applications that may increase the attack surface of your tenant.
    .PARAMETER Context
        Optional context object from Connect-M365Audit; if omitted the current Graph context is used.
    .PARAMETER Since
        Optional [TimeSpan] or [DateTime] to limit stale service principal detection. Defaults to 90 days.
    .PARAMETER OutPath
        Directory path for report files. If omitted no files are written.
    .PARAMETER Format
        One or more output formats: json, csv, md. Defaults to json.
    .PARAMETER PassThru
        When specified returns the report objects on the pipeline.
    .EXAMPLE
        Get-M365AppConsentRisk -OutPath ./out -Format json,csv -Verbose
    .PERMISSIONS
        Graph: Application.Read.All, AppRoleAssignment.Read.All, DelegatedPermissionGrant.Read.All (app-only)
    .DATA COLLECTED
        Application display names, app IDs, consented scopes, secret expiry dates, and risk flags.
    .CAVEATS
        Access to password and certificate credentials may be restricted based on tenant settings.
#>
function Get-M365AppConsentRisk {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [Object]$Context,

        [Parameter(Mandatory=$false)]
        [Object]$Since,

        [Parameter(Mandatory=$false)]
        [string]$OutPath,

        [Parameter(Mandatory=$false)]
        [string[]]$Format = @('json'),

        [switch]$PassThru
    )

    begin {
        if (-not $Since) {
            $Since = (Get-Date).AddDays(-90)
        } elseif ($Since -is [timespan]) {
            $Since = (Get-Date).Add($Since.Negate())
        }
        $highRiskScopes = @('Directory.Read.All','Directory.ReadWrite.All','User.ReadWrite.All','Mail.Read','Mail.ReadWrite','Group.ReadWrite.All')
        $report = @()
    }

    process {
        try {
            if (-not $Context) {
                $Context = Get-MgContext
            }
            Write-Verbose "Retrieving service principals..."
            $servicePrincipals = Get-MgServicePrincipal -All

            foreach ($sp in $servicePrincipals) {
                # Get OAuth grants for the service principal
                $grants = @()
                try {
                    $grants = Get-MgOauth2PermissionGrant -Filter "ClientId eq '$($sp.AppId)'" -All
                } catch {
                    Write-Verbose "Failed to retrieve OAuth grants for $($sp.DisplayName): $($_.Exception.Message)"
                }

                # Consolidate scopes
                $allScopes = @()
                foreach ($grant in $grants) {
                    if ($grant.Scope) {
                        $allScopes += $grant.Scope.Split(' ')
                    }
                }
                $allScopes = $allScopes | Select-Object -Unique

                # Determine if any high-risk scopes are present
                $highRiskGranted = @($allScopes | Where-Object { $highRiskScopes -contains $_ })

                # Evaluate secrets/certificates
                $soonExpiringSecrets = @()
                $expiryStatus = 'OK'
                try {
                    $creds = @($sp.PasswordCredentials + $sp.KeyCredentials)
                    foreach ($cred in $creds) {
                        if ($cred.EndDateTime) {
                            $daysRemaining = [Math]::Round((($cred.EndDateTime) - (Get-Date)).TotalDays)
                            if ($daysRemaining -le 90) {
                                $soonExpiringSecrets += [PSCustomObject]@{
                                    KeyId       = $cred.KeyId
                                    EndDateTime = $cred.EndDateTime
                                    DaysLeft    = $daysRemaining
                                }
                            }
                            if ($daysRemaining -le 30) { $expiryStatus = 'Expires<30d' }
                            elseif ($daysRemaining -le 60) { $expiryStatus = 'Expires<60d' }
                            elseif ($daysRemaining -le 90) { $expiryStatus = 'Expires<90d' }
                        }
                    }
                } catch {
                    Write-Verbose "Failed to evaluate credentials for $($sp.DisplayName): $($_.Exception.Message)"
                }

                # Identify stale service principal by last sign-in (if property available)
                $stale = $false
                try {
                    if ($sp.SignInActivity.LastSignInDateTime) {
                        $lastSignIn = [DateTime]$sp.SignInActivity.LastSignInDateTime
                        if ($lastSignIn -lt $Since) {
                            $stale = $true
                        }
                    }
                } catch {
                    # property may not exist
                }

                $report += [PSCustomObject]@{
                    AppName         = $sp.DisplayName
                    AppId           = $sp.AppId
                    HighRiskScopes  = [string]::Join(',', $highRiskGranted)
                    AllScopes       = [string]::Join(',', $allScopes)
                    ExpiryStatus    = $expiryStatus
                    SecretsExpiring = $soonExpiringSecrets
                    StaleServicePr  = $stale
                }
            }
        } catch {
            Write-Warning "Failed to retrieve app consent information: $($_.Exception.Message)"
        }
    }

    end {
        if ($OutPath) {
            if (-not (Test-Path $OutPath)) {
                New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
            }
            foreach ($fmt in $Format) {
                switch ($fmt.ToLowerInvariant()) {
                    'json' {
                        $jsonPath = Join-Path $OutPath 'M365AppConsentRisk.json'
                        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding utf8
                    }
                    'csv' {
                        $csvPath = Join-Path $OutPath 'M365AppConsentRisk.csv'
                        # Flatten nested secrets for CSV by excluding SecretsExpiring
                        $report | Select-Object AppName,AppId,HighRiskScopes,AllScopes,ExpiryStatus,StaleServicePr | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
                    }
                    'md' {
                        $mdPath = Join-Path $OutPath 'M365AppConsentRisk.md'
                        if ($report.Count -gt 0) {
                            $headers = $report[0].PSObject.Properties.Name
                            $mdLines = @()
                            $mdLines += '| ' + ($headers -join ' | ') + ' |'
                            $mdLines += '| ' + (($headers | ForEach-Object { '---' }) -join ' | ') + ' |'
                            foreach ($row in $report) {
                                $values = @()
                                foreach ($h in $headers) { $values += ($row.$h) }
                                $mdLines += '| ' + ($values -join ' | ') + ' |'
                            }
                            $mdLines | Set-Content -Path $mdPath -Encoding utf8
                        } else {
                            '# No data found' | Set-Content -Path $mdPath -Encoding utf8
                        }
                    }
                }
            }
        }
        if ($PassThru.IsPresent) {
            return $report
        }
    }
}
