# Tests for Identity cmdlets (PrivilegedRoleReport, ConditionalAccessReport, AppConsentRisk)
BeforeAll {
    # Import the module from relative path
    $modulePath = Join-Path $PSScriptRoot -ChildPath '..\src\M365AuditKit'
    Import-Module $modulePath -Force
}

Describe 'Get-M365PrivilegedRoleReport' {
    It 'Should call Graph and return results' {
        # Mock Graph cmdlets
        Mock Get-MgRoleManagementDirectoryRoleAssignment {
            @([PSCustomObject]@{
                Id = 'assignment1'
                RoleDefinitionDisplayName = 'Global Administrator'
                AssignmentType = 'Eligible'
                PrincipalId = 'user1'
            })
        }
        Mock Get-MgUser {
            [PSCustomObject]@{
                Id = 'user1'
                UserPrincipalName = 'user1@example.com'
                DisplayName = 'User One'
            }
        }
        Mock Get-MgUserAuthenticationMethod {
            @('passwordAuthenticationMethod')
        }
        $ctx = [PSCustomObject]@{ Connected = $true }
        $result = Get-M365PrivilegedRoleReport -Context $ctx -PassThru
        Assert-MockCalled Get-MgRoleManagementDirectoryRoleAssignment -Times 1
        Assert-MockCalled Get-MgUser -Times 1
        Assert-MockCalled Get-MgUserAuthenticationMethod -Times 1
        $result | Should -Not -BeNullOrEmpty
        $result[0].RoleName | Should -Be 'Global Administrator'
    }
}

Describe 'Get-M365ConditionalAccessReport' {
    It 'Should call Graph and flag risky policies' {
        Mock Get-MgIdentityConditionalAccessPolicy {
            @([PSCustomObject]@{
                Id = 'policy1'
                DisplayName = 'Allow all users to all apps'
                State = 'enabled'
                Conditions = @{
                    Users = @{ Include = @('All'); Exclude = @() }
                    Applications = @{ Include = @('All'); Exclude = @() }
                }
                GrantControls = @{ BuiltInControls = @() }
            })
        }
        $ctx = [PSCustomObject]@{ Connected = $true }
        $result = Get-M365ConditionalAccessReport -Context $ctx -PassThru
        Assert-MockCalled Get-MgIdentityConditionalAccessPolicy -Times 1
        $result | Should -Not -BeNullOrEmpty
        $result[0].IsRisky | Should -Be $true
    }
}

Describe 'Get-M365AppConsentRisk' {
    It 'Should call Graph to evaluate app consents and return results' {
        Mock Get-MgServicePrincipal {
            @([PSCustomObject]@{
                Id = 'sp1'
                DisplayName = 'Test App'
                AppId = '00000000-0000-0000-0000-000000000001'
                PasswordCredentials = @()
                KeyCredentials = @()
                AppOwnerOrganizationId = 'org1'
                CreatedDateTime = (Get-Date).AddDays(-100)
            })
        }
        Mock Get-MgOauth2PermissionGrant {
            @([PSCustomObject]@{
                Id = 'grant1'
                ClientId = '00000000-0000-0000-0000-000000000001'
                Scope = 'Directory.Read.All Mail.Read'
            })
        }
        $ctx = [PSCustomObject]@{ Connected = $true }
        $result = Get-M365AppConsentRisk -Context $ctx -PassThru
        Assert-MockCalled Get-MgServicePrincipal -Times 1
        Assert-MockCalled Get-MgOauth2PermissionGrant -Times 1
        $result | Should -Not -BeNullOrEmpty
        # The result should contain risk information for the app
    }
}
