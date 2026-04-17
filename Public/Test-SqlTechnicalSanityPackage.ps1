# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Test-SqlTechnicalSanityPackage {
    [CmdletBinding()]
    param()

    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $manifestJsonPath = Join-Path $moduleRoot 'SqlTechnicalSanity.manifest.json'
    $moduleVersion = Get-StsModuleVersion

    $result = [ordered]@{
        ModuleRoot        = $moduleRoot
        ModuleVersion     = $moduleVersion
        ExpectedFileCount = 0
        ActualFileCount   = 0
        MissingFiles      = @()
        HashMismatch      = @()
        VersionHeaderWarn = @()
        Passed            = $true
    }

    if (-not (Test-Path -LiteralPath $manifestJsonPath)) {
        Write-Verbose "Manifest JSON missing: $manifestJsonPath"
        $result.Passed = $false
        return [pscustomobject]$result
    }

    $manifest = Get-Content -LiteralPath $manifestJsonPath -Raw | ConvertFrom-Json
    $result.ExpectedFileCount = [int]$manifest.ExpectedFileCount
    $allFiles = @(Get-ChildItem -LiteralPath $moduleRoot -Recurse -File)
    $result.ActualFileCount = $allFiles.Count

    foreach ($req in @($manifest.RequiredFiles)) {
        $reqPath = Join-Path $moduleRoot $req
        if (-not (Test-Path -LiteralPath $reqPath)) {
            $result.MissingFiles += $req
            $result.Passed = $false
        }
    }

    foreach ($prop in $manifest.Hashes.PSObject.Properties) {
        $path = Join-Path $moduleRoot $prop.Name
        if (Test-Path -LiteralPath $path) {
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            if ($hash -ne $prop.Value) {
                $result.HashMismatch += $prop.Name
                $result.Passed = $false
            }
        }
    }

    foreach ($file in $allFiles | Where-Object Extension -eq '.ps1') {
        $top = Get-Content -LiteralPath $file.FullName -First 6 -ErrorAction SilentlyContinue
        $joined = ($top -join "`n")
        if ($joined -match 'RequiresModuleVersion:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
            try {
                $reqVer = [version]$Matches[1]
                if ($reqVer -gt ([version]$moduleVersion)) {
                    $result.VersionHeaderWarn += $file.FullName.Replace($moduleRoot + '\','')
                    $result.Passed = $false
                }
            } catch {
                $result.VersionHeaderWarn += $file.FullName.Replace($moduleRoot + '\','')
                $result.Passed = $false
            }
        }
    }

    if ($result.ExpectedFileCount -ne $result.ActualFileCount) {
        Write-Verbose ("File count mismatch. Expected {0}, actual {1}" -f $result.ExpectedFileCount, $result.ActualFileCount)
    }

    if ($result.MissingFiles.Count -gt 0) {
        Write-Verbose ("Missing files: " + ($result.MissingFiles -join ', '))
    }

    if ($result.HashMismatch.Count -gt 0) {
        Write-Verbose ("Hash mismatches: " + ($result.HashMismatch -join ', '))
    }

    if ($result.VersionHeaderWarn.Count -gt 0) {
        Write-Verbose ("Version header warnings: " + ($result.VersionHeaderWarn -join ', '))
    }

    [pscustomobject]$result
}
