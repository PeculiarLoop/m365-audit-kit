#Requires -Version 7.2
# Adapted in part from the BECS (Business Email Compromise Search) script by SleepySysadmin (MIT License).
# See THIRD_PARTY_NOTICES.md for attribution.
<#
.SYNOPSIS
    Generates a report of forwarding configurations and mailbox inbox rules, highlighting potentially malicious or risky rules.
.DESCRIPTION
    This cmdlet examines Exchange Online mailboxes for auto‑forwarding settings and mailbox inbox rules.
    It identifies forwarders (ForwardingSMTPAddress or ForwardingAddress) and enumerates inbox rules to detect suspicious patterns such as:
      * rule names that are single characters (e.g., "." or "/");
      * rules that delete or move messages with subjects referencing delivery failures;
      * rules that forward messages to external domains, especially when the subject or body contains payment keywords;
      * rules that move messages to Junk Email, Deleted Items, or RSS Feeds folders.
    The logic for identifying suspicious rules is adapted from the Business Email Compromise Search (BECS) tool (MIT License).
.PARAMETER Context
    A connection context object returned from Connect‑M365Audit. If omitted, the function will use the global $M365AuditContext.
.PARAMETER OutPath
    Directory where output files will be written. If omitted, the function returns objects to the pipeline.
.PARAMETER Format
    Output format when OutPath is specified. Accepts 'json', 'csv', or 'md'. Default is 'json'.
.PARAMETER PassThru
    Return objects to the pipeline even when OutPath is used.
.EXAMPLE
    Get‑M365ForwardingAndInboxRules -Context $ctx -OutPath ./out -Format json -Verbose
    Lists mailboxes with forwarding and suspicious inbox rules, saving the report to JSON and emitting verbose messages.
.PERMISSIONS
    ExchangeOnlineManagement: Mail.Read and/or Mailbox Search role; Graph Mail.Read.All if using Graph to retrieve mailboxes.
.DATA COLLECTED
    Mailbox names, forwarding targets, and inbox rule metadata (names, actions, conditions). Does not collect message contents.
.CAVEATS
    Get-InboxRule can be time‑consuming in large tenants. Consider filtering mailboxes or using the -Since parameter in future versions.
#>
function Get-M365ForwardingAndInboxRules {
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
        # Use provided context or global context
        if (-not $PSBoundParameters.ContainsKey('Context')) {
            if ($Global:M365AuditContext) {
                $Context = $Global:M365AuditContext
            }
        }
        Write-Verbose "Using context: $($Context | Out-String)"
        $results = @()
    }

    process {
        # Ensure we are connected to Exchange
        try {
            Write-Verbose "Retrieving mailboxes..."
            $mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -ErrorAction Stop
        } catch {
            throw "Failed to retrieve mailboxes. Ensure you have connected to Exchange Online and have permissions."
        }

        foreach ($mbx in $mailboxes) {
            # Check forwarding settings
            if ($mbx.ForwardingSMTPAddress -or $mbx.ForwardingAddress -or $mbx.DeliverToMailboxAndForward) {
                $results += [pscustomobject]@{
                    Mailbox      = $mbx.UserPrincipalName
                    Type         = 'Forwarding'
                    Forwarding   = $true
                    ForwardingTarget = ( $mbx.ForwardingSMTPAddress ? $mbx.ForwardingSMTPAddress : ($mbx.ForwardingAddress ? $mbx.ForwardingAddress.Name : $null) )
                    DeliverToMailboxAndForward = $mbx.DeliverToMailboxAndForward
                    IsSuspicious = $false
                    Reason       = 'Mailbox forwarding configured'
                }
            }
            # Retrieve inbox rules
            try {
                $rules = Get-InboxRule -Mailbox $mbx.UserPrincipalName -ErrorAction Stop
            } catch {
                Write-Verbose "Failed to get inbox rules for $($mbx.UserPrincipalName): $_"
                continue
            }

            foreach ($rule in $rules) {
                $suspicious = $false
                $reasons = @()
                # Suspicious rule name like "." or "/"
                if ($rule.Name -match '^[./]{1}$') {
                    $suspicious = $true
                    $reasons += 'Suspicious rule name'
                }
                # Delete actions with delivery failure keywords
                if ($rule.DeleteMessage -and ($rule.SubjectContainsWords -and ($rule.SubjectContainsWords -match '(?i)mail delivery|could not be delivered'))) {
                    $suspicious = $true
                    $reasons += 'Deletes messages with delivery failure keywords'
                }
                # Forward to external addresses
                $forwardAddresses = @()
                foreach ($addr in @($rule.ForwardTo + $rule.ForwardAsAttachmentTo)) {
                    if ($addr) {
                        $forwardAddresses += $addr.Address
                        if ($mbx.PrimarySmtpAddress -and ($addr.Address.Split('@')[-1] -ne $mbx.PrimarySmtpAddress.Split('@')[-1])) {
                            $suspicious = $true
                            $reasons += "Forwards to external address $($addr.Address)"
                        }
                    }
                }
                # Move to suspicious folders
                if ($rule.MoveToFolder -and ($rule.MoveToFolder -in @('Junk E-mail','JunkEmail','Deleted Items','RSS Feeds'))) {
                    $suspicious = $true
                    $reasons += "Moves messages to $($rule.MoveToFolder)"
                }
                if ($suspicious) {
                    $results += [pscustomobject]@{
                        Mailbox    = $mbx.UserPrincipalName
                        Type       = 'InboxRule'
                        RuleName   = $rule.Name
                        Actions    = ($rule.Actions -join ',')
                        SubjectContainsWords = ($rule.SubjectContainsWords -join ',')
                        ForwardTo  = ($forwardAddresses -join ',')
                        MoveToFolder = $rule.MoveToFolder
                        DeleteMessage = $rule.DeleteMessage
                        IsSuspicious = $true
                        Reason       = ($reasons -join '; ')
                    }
                }
            }
        }
    }

    end {
        if ($OutPath) {
            # Ensure directory exists
            $resolvedOutPath = Resolve-Path -Path $OutPath -ErrorAction SilentlyContinue
            if (-not $resolvedOutPath) {
                New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
                $resolvedOutPath = Resolve-Path -Path $OutPath
            }
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            switch ($Format) {
                'json' {
                    $filePath = Join-Path $resolvedOutPath "ForwardingAndInboxRules_$timestamp.json"
                    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding utf8
                }
                'csv' {
                    $filePath = Join-Path $resolvedOutPath "ForwardingAndInboxRules_$timestamp.csv"
                    $results | Export-Csv -Path $filePath -NoTypeInformation -Force
                }
                'md' {
                    $filePath = Join-Path $resolvedOutPath "ForwardingAndInboxRules_$timestamp.md"
                    $mdLines = @()
                    $mdLines += "# Forwarding and Inbox Rules Audit"
                    $mdLines += ""
                    $mdLines += "|Mailbox|Type|RuleName|Actions|SubjectContainsWords|ForwardTo|MoveToFolder|DeleteMessage|Reason|"
                    $mdLines += "|---|---|---|---|---|---|---|---|"
                    foreach ($item in $results) {
                        $mdLines += "|$($item.Mailbox)|$($item.Type)|$($item.RuleName)|$($item.Actions)|$($item.SubjectContainsWords)|$($item.ForwardTo)|$($item.MoveToFolder)|$($item.DeleteMessage)|$($item.Reason)|"
                    }
                    $mdLines | Out-File -FilePath $filePath -Encoding utf8
                }
            }
            Write-Verbose "Exported results to $filePath"
            if ($PassThru) {
                return $results
            }
        } else {
            return $results
        }
    }
}
