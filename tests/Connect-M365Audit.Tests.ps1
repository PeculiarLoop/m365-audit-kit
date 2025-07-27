# Tests for Connect-M365Audit function
BeforeAll {
    # Import the module from relative path
    $modulePath = Join-Path $PSScriptRoot -ChildPath '..\src\M365AuditKit'
    Import-Module $modulePath -Force
}

Describe "Connect-M365Audit" {
    Context "Delegated Auth (Interactive) without Exchange" {
        It "should call Connect-MgGraph and return context" {
            Mock -CommandName Connect-MgGraph -MockWith {
                $script:graphCtx = @{ Connected = $true }
            }
            Mock -CommandName Get-MgContext -MockWith { return $null }
            Mock -CommandName Connect-ExchangeOnline -MockWith {}
            $ctx = Connect-M365Audit -PassThru
            Assert-MockCalled -CommandName Connect-MgGraph -Times 1 -Exactly
            Assert-MockCalled -CommandName Connect-ExchangeOnline -Times 0
            $ctx.Graph | Should -Not -BeNullOrEmpty
            $ctx.Exchange | Should -BeNullOrEmpty
        }
    }

    Context "Certificate-based app-only auth with Exchange" {
        It "should call Connect-MgGraph and Connect-ExchangeOnline using certificate" {
            Mock -CommandName Connect-MgGraph -MockWith {
                $script:graphCtx = @{ Connected = $true }
            }
            Mock -CommandName Get-MgContext -MockWith { return $null }
            Mock -CommandName Connect-ExchangeOnline -MockWith {
                $script:exoCtx = @{ Connected = $true }
            }
            $ctx = Connect-M365Audit -TenantId "11111111-2222-3333-4444-555555555555" -ClientId "00000000-1111-2222-3333-444444444444" -CertificateThumbprint "ABC123DEF" -ConnectExchange -PassThru
            Assert-MockCalled -CommandName Connect-MgGraph -Times 1
            Assert-MockCalled -CommandName Connect-ExchangeOnline -Times 1
            $ctx.Graph | Should -Not -BeNullOrEmpty
            $ctx.Exchange | Should -Not -BeNullOrEmpty
        }
    }

    Context "Reuses existing Graph connection" {
        It "should not call Connect-MgGraph when session exists" {
            Mock -CommandName Get-MgContext -MockWith {
                return @{ Connected = $true }
            }
            Mock -CommandName Connect-MgGraph -MockWith {}
            Mock -CommandName Connect-ExchangeOnline -MockWith {}
            $ctx = Connect-M365Audit -PassThru
            Assert-MockCalled -CommandName Get-MgContext -Times 1
            Assert-MockCalled -CommandName Connect-MgGraph -Times 0
        }
    }
}
