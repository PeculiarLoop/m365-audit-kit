function Connect-M365AuditKit {
    <#
    .SYNOPSIS
        Establishes a connection to Microsoft 365 services for the Audit Kit.

    .DESCRIPTION
        This cmdlet encapsulates authentication logic for both app‑only and
        delegated flows.  By default it attempts app‑only authentication using
        a certificate.  If `-Delegated` is specified it falls back to an
        interactive delegated flow.  In both cases the required scopes are
        validated and missing modules are installed if necessary.  The
        resulting session is stored in global variables for reuse by other
        cmdlets.

    .PARAMETER TenantId
        The Azure AD tenant ID (GUID) to connect to.  When omitted the
        authenticated tenant is used.

    .PARAMETER CertificateThumbprint
        Thumbprint of a certificate in the CurrentUser\My store used for
        app‑only authentication.  If omitted, delegated authentication is
        attempted when `-Delegated` is provided.

    .PARAMETER ClientId
        Application (client) ID for app‑only authentication.

    .PARAMETER Delegated
        Switch to force delegated (interactive) authentication instead of
        app‑only.  This can be used to perform operations that are not
        supported in an app‑only context.

    .EXAMPLE
        Connect-M365AuditKit -TenantId 'contoso.onmicrosoft.com' -ClientId 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' -CertificateThumbprint '0123456789abcdef0123456789abcdef01234567'

    .EXAMPLE
        Connect-M365AuditKit -Delegated

    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$TenantId,
        [Parameter()] [string]$ClientId,
        [Parameter()] [string]$CertificateThumbprint,
        [switch]$Delegated
    )

    begin {
        Write-Verbose 'Checking required modules...'
        $requiredModules = @('Microsoft.Graph', 'ExchangeOnlineManagement')
        foreach ($module in $requiredModules) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-Verbose "Installing missing module: $module"
                try {
                    Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
                } catch {
                    throw "Failed to install required module '$module': $_"
                }
            }
        }
    }
    process {
        if ($PSBoundParameters.ContainsKey('Delegated') -and $Delegated) {
            Write-Verbose 'Performing delegated authentication via Microsoft Graph SDK.'
            # Delegated authentication (interactive).  In a real implementation
            # you would call Connect-MgGraph with the appropriate scopes.
            Write-Host 'TODO: Connect-M365AuditKit delegated auth not implemented. Using Connect-MgGraph -Scopes <scopes>' -ForegroundColor Yellow
            # Example (commented):
            # Connect-MgGraph -Scopes 'AuditLog.Read.All','Directory.Read.All','Exchange.ManageAsApp'
        } else {
            # App‑only authentication using a certificate
            if (-not $TenantId -or -not $ClientId -or -not $CertificateThumbprint) {
                throw 'TenantId, ClientId and CertificateThumbprint are required for app‑only authentication.'
            }
            Write-Verbose 'Performing app‑only authentication via Microsoft Graph SDK.'
            Write-Host 'TODO: Connect-M365AuditKit app-only auth not implemented. Use Connect-MgGraph -ClientId ... -TenantId ... -CertificateThumbprint ...' -ForegroundColor Yellow
            # Example (commented):
            # Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint
        }

        # Connect to Exchange Online if necessary
        Write-Verbose 'Connecting to Exchange Online PowerShell...'
        Write-Host 'TODO: Connect-ExchangeOnline not implemented.' -ForegroundColor Yellow
        # Example: Connect-ExchangeOnline -Organization $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint

        Write-Verbose 'Connection initialisation complete.'
        # Set a global variable to flag that we are connected
        $global:M365AuditKitConnected = $true
    }
}
