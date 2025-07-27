<#
    .SYNOPSIS
        Generates a report of privileged role assignments and identifies potential risks.
    .DESCRIPTION
        Queries Microsoft Entra ID (Azure AD) via Microsoft Graph to retrieve role assignments
        and produces a structured report including assignment type (eligible or active),
        MFA status for the user, sign-in risk (if available), and whether the account is
        considered a break-glass account. Designed for HIPAA/NIST/CIS compliance assessments.
    .PARAMETER Context
        Optional context object returned by Connect-M365Audit. If not supplied the current
        Graph connection is used.
    .PARAMETER Since
        Optional [TimeSpan] or [DateTime] limiting sign-in and audit lookback window.
        If omitted, defaults to 30 days.
    .PARAMETER OutPath
        Directory path where reports are written. If not specified no files are created.
    .PARAMETER Format
        One or more output formats: json, csv, or md. Defaults to json.
    .PARAMETER PassThru
        When set, the report objects are written to the pipeline. By default the function
        writes nothing to the pipeline.
    .EXAMPLE
        Get-M365PrivilegedRoleReport -Since 14d -OutPath ./out -Format json,csv -Verbose
    .PERMISSIONS
        Graph: RoleManagement.Read.Directory, User.Read.All, Directory.Read.All (app-only)
    .DATA COLLECTED
        User principal names, role names, assignment types, MFA methods, basic risk flags.
    .CAVEATS
        This cmdlet does not download or expose any personal data beyond account identifiers.
        Sign-in risk detection requires Azure AD Identity Protection licensing.
#>
function Get-M365PrivilegedRoleReport {
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
        # Initialize lookback
        if (-not $Since) {
            $Since = (Get-Date).AddDays(-30)
        } elseif ($Since -is [timespan]) {
            $Since = (Get-Date).Add($Since.Negate())
        }
        $report = @()
    }

    process {
        try {
            # Ensure Graph context
            if (-not $Context) {
                $Context = Get-MgContext
            }

            Write-Verbose "Retrieving directory role assignments..."
            $assignments = Get-MgRoleManagementDirectoryRoleAssignment -ConsistencyLevel eventual -All

            foreach ($assignment in $assignments) {
                # Retrieve user details
                $user = Get-MgUser -UserId $assignment.PrincipalId -Select 'Id,UserPrincipalName,DisplayName'

                # Fetch MFA methods for the user
                $authMethods = @()
                try {
                    $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction SilentlyContinue
                } catch {
                    Write-Verbose "Failed to retrieve authentication methods for $($user.UserPrincipalName): $($_.Exception.Message)"
                }
                $mfaEnabled = ($authMethods.Count -gt 0)

                # Determine assignment type; property names differ depending on Graph version
                $assignmentType = if ($assignment.AssignmentType) { $assignment.AssignmentType } else { 'Unknown' }

                # Identify break-glass accounts by pattern
                $isBreakGlass = $false
                if ($user.UserPrincipalName -match 'breakglass|emergency' -or $user.DisplayName -match 'breakglass|emergency') {
                    $isBreakGlass = $true
                }

                # Placeholder for sign-in risk; retrieving risk events requires Identity Protection permissions
                $signInRisk = 'Unknown'

                # Build result object
                $report += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName       = $user.DisplayName
                    RoleName          = $assignment.RoleDefinitionDisplayName
                    AssignmentType    = $assignmentType
                    MFAEnabled        = $mfaEnabled
                    SignInRisk        = $signInRisk
                    BreakGlass        = $isBreakGlass
                }
            }

        } catch {
            Write-Warning "An error occurred while generating the privileged role report: $($_.Exception.Message)"
        }
    }

    end {
        # Export if requested
        if ($OutPath) {
            if (-not (Test-Path $OutPath)) {
                New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
            }
            foreach ($fmt in $Format) {
                switch ($fmt.ToLowerInvariant()) {
                    'json' {
                        $jsonPath = Join-Path $OutPath 'M365PrivilegedRoleReport.json'
                        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding utf8
                    }
                    'csv' {
                        $csvPath = Join-Path $OutPath 'M365PrivilegedRoleReport.csv'
                        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
                    }
                    'md' {
                        $mdPath = Join-Path $OutPath 'M365PrivilegedRoleReport.md'
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
