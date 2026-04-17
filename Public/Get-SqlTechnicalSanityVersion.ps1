# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Get-SqlTechnicalSanityVersion {
    [CmdletBinding()]
    param()

    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $manifestJsonPath = Join-Path $moduleRoot 'SqlTechnicalSanity.manifest.json'
    $moduleVersion = Get-StsModuleVersion

    $buildLabel = $null
    $buildDate = $null
    if (Test-Path -LiteralPath $manifestJsonPath) {
        try {
            $json = Get-Content -LiteralPath $manifestJsonPath -Raw | ConvertFrom-Json
            $buildLabel = $json.BuildLabel
            $buildDate = $json.BuildDate
        } catch {}
    }

    [pscustomobject]@{
        ModuleName    = 'SqlTechnicalSanity'
        ModuleVersion = $moduleVersion
        BuildLabel    = $buildLabel
        BuildDate     = $buildDate
    }
}
