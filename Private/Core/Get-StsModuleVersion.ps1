# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Get-StsModuleVersion {
    [CmdletBinding()]
    param()

    $manifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) '..\SqlTechnicalSanity.psd1'
    $manifestPath = [System.IO.Path]::GetFullPath($manifestPath)

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Module manifest not found: $manifestPath"
    }

    (Import-PowerShellDataFile -LiteralPath $manifestPath).ModuleVersion
}
