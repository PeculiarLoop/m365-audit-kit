<#
    virtuALLY.Gui.ps1

    Entrypoint for launching the virtuALLY GUI.  This script uses
    Windows Presentation Foundation (WPF) to build a dark‑themed tabbed
    interface on top of the enhanced M365 Audit Kit.  It loads XAML
    resources from the `gui` folder, merges the theme dictionary and
    wires up basic event handlers that call into the PowerShell module.

    NOTE: This GUI is Windows only and requires PowerShell 7+ with
    Windows‑compatible assemblies.  Many operations are stubbed or
    simplified; extend them as needed to implement full functionality.
#>

param(
    [switch]$NoInitialConnect
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Ensure module is imported
Import-Module (Join-Path $PSScriptRoot '..' 'M365AuditKit.psd1') -Force

# Load Theme
$themePath = Join-Path $PSScriptRoot 'Theme.xaml'
$themeXaml = Get-Content -Path $themePath -Raw
[System.Windows.Application]::Current.Resources.MergedDictionaries.Add(
    [System.Windows.Markup.XamlReader]::Parse($themeXaml)
)

# Helper to load a view from XAML file
function Load-View {
    param([string]$Name)
    $path = Join-Path $PSScriptRoot "Views/$Name.xaml"
    $xml  = [xml](Get-Content -Path $path -Raw)
    return [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xml))
}

# Create Main Window
$window = New-Object System.Windows.Window
$window.Title = 'virtuALLY M365 Audit Kit'
$window.Width  = 800
$window.Height = 600
$window.WindowStartupLocation = 'CenterScreen'

# Create TabControl
$tabs = New-Object System.Windows.Controls.TabControl

function New-Tab {
    param([string]$Header,[object]$Content)
    $tab = New-Object System.Windows.Controls.TabItem
    $tab.Header = $Header
    $tab.Content = $Content
    return $tab
}

# Load views
$homeView          = Load-View -Name 'Home'
$quickAuditsView   = Load-View -Name 'QuickAudits'
$investigationView = Load-View -Name 'Investigation'
$findingsView      = Load-View -Name 'Findings'
$reportsView       = Load-View -Name 'ReportsExport'
$schedulerView     = Load-View -Name 'Scheduler'

# Add tabs
$tabs.Items.Add((New-Tab -Header 'Home'          -Content $homeView))       | Out-Null
$tabs.Items.Add((New-Tab -Header 'Quick Audits'   -Content $quickAuditsView))| Out-Null
$tabs.Items.Add((New-Tab -Header 'Investigation' -Content $investigationView))| Out-Null
$tabs.Items.Add((New-Tab -Header 'Findings'      -Content $findingsView))    | Out-Null
$tabs.Items.Add((New-Tab -Header 'Reports'       -Content $reportsView))     | Out-Null
$tabs.Items.Add((New-Tab -Header 'Scheduler'     -Content $schedulerView))   | Out-Null

$window.Content = $tabs

# Store a collection for findings
$script:FindingsCollection = New-Object System.Collections.ObjectModel.ObservableCollection[psobject]

## Wire up event handlers

# Connect button
$homeView.FindName('ConnectButton').Add_Click({
    try {
        # For demonstration always use delegated auth
        Connect-M365AuditKit -Delegated
        [System.Windows.MessageBox]::Show('Connected to M365 successfully.','Connected',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Failed to connect: $_",'Error',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    }
})

# Run quick audit
$quickAuditsView.FindName('RunAuditButton').Add_Click({
    $selectedProfile = ($quickAuditsView.FindName('ProfileCombo').SelectedItem.Content)
    try {
        $outDir = Join-Path -Path $env:TEMP -ChildPath 'virtually_audit'
        $results = Start-M365QuickAudit -Profile $selectedProfile -DaysBack 7 -OutFolder $outDir -Verbose:$false
        # Clear previous
        $script:FindingsCollection.Clear()
        foreach ($r in $results) { $script:FindingsCollection.Add($r) }
        $findingsView.FindName('FindingsGrid').ItemsSource = $script:FindingsCollection
        $tabs.SelectedIndex = 3 # Switch to Findings tab
        [System.Windows.MessageBox]::Show("Quick audit completed. Results loaded.",'Audit Complete',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Audit failed: $_",'Error',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    }
})

# Run investigation
$investigationView.FindName('RunInvestigationButton').Add_Click({
    try {
        $start  = $investigationView.FindName('StartDatePicker').SelectedDate
        $end    = $investigationView.FindName('EndDatePicker').SelectedDate
        $users  = ($investigationView.FindName('UsersBox').Text -split ',').Trim() | Where-Object { $_ -ne '' }
        $ops    = ($investigationView.FindName('OperationsBox').Text -split ',').Trim() | Where-Object { $_ -ne '' }
        $outDir = Join-Path -Path $env:TEMP -ChildPath 'virtually_investigation'
        $results = Invoke-M365Investigation -Start $start -End $end -Users $users -Operations $ops -Sources @('UAL') -OutFolder $outDir -Verbose:$false
        $script:FindingsCollection.Clear()
        foreach ($r in $results) { $script:FindingsCollection.Add($r) }
        $findingsView.FindName('FindingsGrid').ItemsSource = $script:FindingsCollection
        $tabs.SelectedIndex = 3
        [System.Windows.MessageBox]::Show("Investigation completed. Results loaded.",'Investigation Complete',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Investigation failed: $_",'Error',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    }
})

# Open latest report button
$reportsView.FindName('OpenReportButton').Add_Click({
    $outDirs = @('virtually_audit','virtually_investigation') | ForEach-Object { Join-Path $env:TEMP $_ }
    $report = $null
    foreach ($dir in $outDirs) {
        $candidate = Join-Path $dir 'report.html'
        if (Test-Path $candidate) { $report = $candidate }
    }
    if ($report) {
        Start-Process -FilePath $report
    } else {
        [System.Windows.MessageBox]::Show('No report found. Run an audit or investigation first.','No Report',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
    }
})

# Show window
$window.Content = $tabs
$window.ShowDialog() | Out-Null
