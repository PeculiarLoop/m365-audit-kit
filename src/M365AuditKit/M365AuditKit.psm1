# M365AuditKit module file
# This module loads and exports cmdlets for auditing Microsoft 365.
# It automatically dot-sources all .ps1 files in the module directory.

# Requires PowerShell 7.2 or later
#requires -Version 7.2

# Dot-source all PowerShell scripts in this directory
Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}

# Export public functions explicitly
Export-ModuleMember -Function 'Connect-M365Audit'
