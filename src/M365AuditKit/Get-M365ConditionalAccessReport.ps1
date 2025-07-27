<#
    .SYNOPSIS
        Generates a report of Conditional Access (CA) policies and flags risky configurations.
    .DESCRIPTION
        Retrieves all conditional access policies via Microsoft Graph and summarizes their
        assignments, grant controls, and conditions. The report identifies policies that
        apply to all users and all cloud apps without enforcement controls, as well as broad
        exclusions that may weaken overall posture. This helps satisfy HIPAA/NIST/CIS
        requirements by ensuring CA policies enforce MFA and session controls appropriately.
    .PARAMETER Context
        Optional context object from Connect-M365Audit; if omitted the current Graph context is used.
    .PARAMETER OutPath
        Directory path where reports will be written. If omitted no files are created.
    .PARAMETER Format
        One or more output formats: json, csv, md. Defaults to json.
    .PARAMETER PassThru
        When specified, returns the report objects on the pipeline.
    .EXAMPLE
        Get-M365ConditionalAccessReport -OutPath ./out -Format json,md -Verbose
    .PERMISSIONS
        Graph: Policy.Read.All (app-only)
    .DATA COLLECTED
        Conditional Access policy names, states, assignments, exclusions, grant controls,
        and basic risk flags.
    .CAVEATS
        This cmdlet does not evaluate the effectiveness of grant controls; review manually.
#>
function Get-M365ConditionalAccessReport {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [Object]$Context,

        [Parameter(Mandatory=$false)]
        [string]$OutPath,

        [Parameter(Mandatory=$false)]
        [string[]]$Format = @('json'),

        [switch]$PassThru
    )

    begin {
        $report = @()
    }

    process {
        try {
            if (-not $Context) {
                $Context = Get-MgContext
            }
            Write-Verbose "Retrieving Conditional Access policies..."
            # Using beta Graph due to CA endpoints; however Graph SDK maps both
            $policies = Get-MgIdentityConditionalAccessPolicy -All

            foreach ($policy in $policies) {
                # Determine if policy is in a risky configuration
                $allUsers = $false
                $allApps  = $false
                $hasGrantControls = $false
                $hasExclusions = $false

                # Evaluate assignments
                if ($policy.Conditions.Users.Include -contains 'All') {
                    $allUsers = $true
                }
                if ($policy.Conditions.Applications.Include -contains 'All') {
                    $allApps = $true
                }
                if ($policy.GrantControls) {
                    $hasGrantControls = ($policy.GrantControls.BuiltInControls.Count -gt 0 -or $policy.GrantControls.CustomAuthenticationFactors.Count -gt 0)
                }
                if ($policy.Conditions.Users.Exclude -and $policy.Conditions.Users.Exclude.Count -gt 0) {
                    $hasExclusions = $true
                }

                # Flag risky combinations: all users + all apps without grant controls
                $riskyCombination = $false
                if ($allUsers -and $allApps -and -not $hasGrantControls) {
                    $riskyCombination = $true
                }

                # Build result object
                $report += [PSCustomObject]@{
                    PolicyName       = $policy.DisplayName
                    State            = $policy.State
                    AllUsers         = $allUsers
                    AllApps          = $allApps
                    GrantControls    = [string]::Join(',', $policy.GrantControls.BuiltInControls)
                    ExcludedUsers    = [string]::Join(',', $policy.Conditions.Users.Exclude)
                    RiskyCombination = $riskyCombination
                }
            }
        } catch {
            Write-Warning "Failed to retrieve Conditional Access policies: $($_.Exception.Message)"
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
                        $jsonPath = Join-Path $OutPath 'M365ConditionalAccessReport.json'
                        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding utf8
                    }
                    'csv' {
                        $csvPath = Join-Path $OutPath 'M365ConditionalAccessReport.csv'
                        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
                    }
                    'md' {
                        $mdPath = Join-Path $OutPath 'M365ConditionalAccessReport.md'
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
