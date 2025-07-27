BeforeAll {
    # Import the module from the parent src directory
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\M365AuditKit'
    Import-Module (Join-Path $modulePath 'M365AuditKit.psd1') -Force
}

Describe 'Get-M365ForwardingAndInboxRules' {
    BeforeAll {
        # Mock Exchange cmdlets
        Mock -CommandName Get-Mailbox -MockWith { [pscustomobject]@{UserPrincipalName='user@contoso.com'; ForwardingSmtpAddress='evil@external.com'; ForwardingAddress=$null} }
        Mock -CommandName Get-InboxRule -MockWith {
            [pscustomobject]@{
                Name = '.'
                Description = 'Delete all messages'
                Enabled = $true
                DeleteMessage = $true
                SubjectContainsWords = @('invoice')
                ForwardTo = @('evil@external.com')
                MoveToFolder = $null
            }
        }
    }
    It 'Returns suspicious inbox rules and forwarding' {
        $context = [pscustomobject]@{}
        $results = Get-M365ForwardingAndInboxRules -Context $context -PassThru
        $results | Should -Not -BeNullOrEmpty
        # Verify mocks were called
        Assert-MockCalled -CommandName Get-Mailbox -Times 1
        Assert-MockCalled -CommandName Get-InboxRule -Times 1
    }
}

Describe 'Get-M365MailAuthPosture' {
    BeforeAll {
        Mock -CommandName Get-AcceptedDomain -MockWith { [pscustomobject]@{DomainName='contoso.com'} }
        Mock -CommandName Resolve-DnsName -MockWith {
            param($Name, $Type)
            if ($Name -like '_dmarc*') {
                return @{ Strings = @('v=DMARC1; p=reject; rua=mailto:dmarc@contoso.com') }
            } elseif ($Name -like '*._domainkey*') {
                return @{ Strings = @('v=DKIM1; k=rsa; p=ABC123') }
            } else {
                return @{ Strings = @('v=spf1 include:spf.protection.outlook.com -all') }
            }
        }
        Mock -CommandName Get-DkimSigningConfig -MockWith { [pscustomobject]@{DomainName='contoso.com'; Enabled=$true} }
        Mock -CommandName Get-SafeLinksPolicy -MockWith { [pscustomobject]@{Name='Default'; EnableSafeLinksForEmail=$true} }
        Mock -CommandName Get-SafeAttachmentPolicy -MockWith { [pscustomobject]@{Name='Default'; Action='Block'} }
        Mock -CommandName Get-AntiPhishPolicy -MockWith { [pscustomobject]@{Name='Default'; Enabled=$true} }
    }
    It 'Returns mail authentication posture' {
        $context = [pscustomobject]@{}
        $posture = Get-M365MailAuthPosture -Context $context -PassThru
        $posture | Should -Not -BeNullOrEmpty
        Assert-MockCalled -CommandName Get-AcceptedDomain -Times 1
        Assert-MockCalled -CommandName Get-DkimSigningConfig -Times 1
        Assert-MockCalled -CommandName Get-SafeLinksPolicy -Times 1
        Assert-MockCalled -CommandName Get-SafeAttachmentPolicy -Times 1
        Assert-MockCalled -CommandName Get-AntiPhishPolicy -Times 1
    }
}
