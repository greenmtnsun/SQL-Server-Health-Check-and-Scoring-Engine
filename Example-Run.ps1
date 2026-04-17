$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $moduleRoot 'SqlTechnicalSanity.psd1') -Force

Initialize-SqlTechnicalSanityDefaults -ModuleRoot $moduleRoot -Force
Test-SqlTechnicalSanityPackage | Format-List

$baseline = "C:\SYSADMIN\DATA\SqlTechnicalSanity-20260330-172330.json"

$result = Invoke-SqlTechnicalSanity `
    -SqlInstance @('localhost') `
    -OutputDirectory "C:\SYSADMIN\DATA" `
    -BaselineJsonPath $baseline `
    -PassThru

$result.Score | Format-List

if (Test-Path -LiteralPath $baseline) {
    $cmp = Compare-SqlTechnicalSanityBaseline `
        -CurrentJsonPath $result.JsonPath `
        -BaselineJsonPath $baseline

    $cmp | Format-List
    $cmp.DomainDelta | Format-Table Collector, CurrentScore, BaselineScore, Delta -AutoSize
} else {
    Write-Host "Baseline file not found: $baseline"
}

$result.HtmlPath
$result.JsonPath
