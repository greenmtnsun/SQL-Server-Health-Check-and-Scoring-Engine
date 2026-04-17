#requires -Version 5.1
Set-StrictMode -Version 2.0
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Private') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Public') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function @(
    'Invoke-SqlTechnicalSanity',
    'Invoke-SqlTechnicalSanityWithPolicy',
    'Get-SqlTechnicalSanityCollector',
    'Get-SqlTechnicalSanityCheck',
    'ConvertTo-SqlTechnicalSanityHtml',
    'ConvertTo-SqlTechnicalSanityJson',
    'Export-SqlTechnicalSanityReport',
    'Test-SqlTechnicalSanityPackage',
    'Compare-SqlTechnicalSanityBaseline',
    'Get-SqlTechnicalSanityExecutiveSummary',
    'Invoke-SqlTechnicalSanityFleetRollup',
    'Export-SqlTechnicalSanityFleetRollupHtml',
    'Get-SqlTechnicalSanityTopActions',
    'Get-SqlTechnicalSanityThresholds',
    'Get-SqlTechnicalSanityIgnoreTemplate',
    'Initialize-SqlTechnicalSanityDefaults'
)
. "$PSScriptRoot\Private\Core\Get-StsModuleVersion.ps1"
. "$PSScriptRoot\Public\Test-SqlTechnicalSanityPackage.ps1"
. "$PSScriptRoot\Public\Get-SqlTechnicalSanityVersion.ps1"
