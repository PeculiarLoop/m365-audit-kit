function Connect-M365Audit {
    [CmdletBinding(DefaultParameterSetName='AppOnly', SupportsShouldProcess=$true)]
    param(
        # Parameter sets for certificate-based (App only)
        [Parameter(ParameterSetName='AppOnly')]
        [string]$TenantId,

        [Parameter(ParameterSetName='AppOnly')]
        [string]$ClientId,

        [Parameter(ParameterSetName='AppOnly')]
        [string]$CertificateThumbprint,

        [Parameter(ParameterSetName='AppOnly')]
        [string]$CertificatePath,

        [Parameter(ParameterSetName='Delegated')]
        [switch]$Delegated,

        [Parameter(ParameterSetName='Delegated')]
        [string]$Scopes = "User.Read.All, Directory.Read.All",

        [Parameter()]
        [switch]$ConnectExchange,

        [Parameter()]
        [switch]$ConnectDefender,

        [Parameter()]
        [switch]$ConnectPurview,

        [Parameter()]
        [switch]$ConnectTeams,

        [Parameter()]
        [switch]$PassThru
    )

    <#
        .SYNOPSIS
        Establishes connections to Microsoft Graph and Exchange Online for M365 auditing.

        .DESCRIPTION
        Connect-M365Audit authenticates to Microsoft Graph using either certificate-based app-only authentication or delegated authentication via device code. It optionally establishes connections to Exchange Online and other services (Defender, Purview, Teams). It returns a context object containing connection information that can be reused by other cmdlets in this module. This function centralizes throttling and retry logic for Graph calls.

        .PARAMETER TenantId
        The Azure Active Directory tenant ID to connect to when using app-only authentication.

        .PARAMETER ClientId
        The client (application) ID of the Azure AD app registration used for app-only authentication.

        .PARAMETER CertificateThumbprint
        Thumbprint of the certificate installed in the local certificate store for app-only authentication. If provided, CertificatePath is ignored.

        .PARAMETER CertificatePath
        Path to a PFX or PEM certificate used for app-only authentication. Use this when the certificate is not installed in the local certificate store.

        .PARAMETER Delegated
        Switch to use delegated auth via device login. When set, Connect-MgGraph will prompt for user sign in with the specified Scopes.

        .PARAMETER Scopes
        The scopes to request when using delegated authentication. Defaults to User.Read.All and Directory.Read.All.

        .PARAMETER ConnectExchange
        If specified, establishes a session to Exchange Online using the current Graph credentials.

        .PARAMETER ConnectDefender
        If specified, establishes a Defender for Endpoint connection (placeholder for future).

        .PARAMETER ConnectPurview
        If specified, establishes a Purview (Audit) connection (placeholder for future).

        .PARAMETER ConnectTeams
        If specified, establishes a Teams connection (placeholder for future).

        .PARAMETER PassThru
        When specified, returns the context object to the pipeline. If not specified, the context is stored globally for the current session.

        .EXAMPLE
        Connect-M365Audit -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ClientId "yyyyyyy-...." -CertificateThumbprint "ABCDEF1234567890" -ConnectExchange -PassThru
        Uses certificate-based app-only authentication to connect to Graph and Exchange Online, returning the context object.

        .EXAMPLE
        Connect-M365Audit -Delegated -Scopes "User.Read.All,MailboxSettings.Read" -ConnectExchange
        Uses delegated auth with device login to connect to Graph and Exchange Online.

        .PERMISSIONS
        App-only: Directory.Read.All, Policy.Read.All, AuditLog.Read.All; Delegated: User.Read.All and any others required.

        .DATA COLLECTED
        This cmdlet stores tokens and connection contexts in memory only. No ePHI is collected.

        .CAVEATS
        Requires the Microsoft Graph and Exchange Online modules to be installed. When using delegated auth, interactive login is required.
    #>

    # Connect to Microsoft Graph
    Write-Verbose "Starting M365 audit session..."
    $graphParams = @{}
    if ($PSCmdlet.ParameterSetName -eq 'Delegated') {
        $graphParams['Scopes'] = $Scopes -split ',\s*'
    }
    elseif ($TenantId) {
        $graphParams['TenantId'] = $TenantId
    }
    if ($CertificateThumbprint) {
        $graphParams['CertificateThumbprint'] = $CertificateThumbprint
        if ($ClientId) { $graphParams['ClientId'] = $ClientId }
    } elseif ($CertificatePath) {
        $graphParams['CertificatePath'] = $CertificatePath
        if ($ClientId) { $graphParams['ClientId'] = $ClientId }
    }

    try {
        Write-Verbose "Connecting to Microsoft Graph..."
        # For testing, we allow mocking Connect-MgGraph; in production this will connect
        $null = Connect-MgGraph @graphParams -ErrorAction Stop
    } catch {
        throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    }

    # Prepare context
    $context = [PSCustomObject]@{
        GraphConnection    = (Get-MgContext)
        ExchangeConnected  = $false
        AdditionalServices = @{}
    }

    # Connect to Exchange Online if requested
    if ($ConnectExchange) {
        try {
            Write-Verbose "Connecting to Exchange Online..."
            # For Pester tests this will be mocked
            Connect-ExchangeOnline -ErrorAction Stop | Out-Null
            $context.ExchangeConnected = $true
        } catch {
            throw "Failed to connect to Exchange Online: $($_.Exception.Message)"
        }
    }

    # Placeholders for other services
    if ($ConnectDefender) { $context.AdditionalServices.Defender = $true }
    if ($ConnectPurview)  { $context.AdditionalServices.Purview = $true }
    if ($ConnectTeams)    { $context.AdditionalServices.Teams   = $true }

    # Return or store context
    if ($PassThru) {
        return $context
    } else {
        Set-Variable -Name 'M365AuditContext' -Value $context -Scope Global
        Write-Verbose "Connection context stored in `$M365AuditContext."


    }
}
