$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $moduleRoot 'SqlTechnicalSanity.psd1') -Force

Test-SqlTechnicalSanityPackage | Format-List

Initialize-SqlTechnicalSanityDefaults -ModuleRoot $moduleRoot -Force

$baseline = "C:\SYSADMIN\DATA\SqlTechnicalSanity-20260330-172330.json"

$result = Invoke-SqlTechnicalSanity `
    -SqlInstance @('localhost') `
    -OutputDirectory "C:\SYSADMIN\DATA" `
    -PassThru

$result.Score | Format-List

if (Test-Path -LiteralPath $baseline) {
    $cmp = Compare-SqlTechnicalSanityBaseline `
        -CurrentJsonPath $result.JsonPath `
        -BaselineJsonPath $baseline

    $cmp | Format-List
    $cmp.DomainDelta | Format-Table Collector, CurrentScore, BaselineScore, Delta -AutoSize

    $data = Get-Content -LiteralPath $result.JsonPath -Raw | ConvertFrom-Json
    $html = ConvertTo-SqlTechnicalSanityHtml `
        -Run $data.run `
        -Findings @($data.findings) `
        -Score $data.score `
        -BaselineJsonPath $baseline

    Set-Content -LiteralPath $result.HtmlPath -Value $html -Encoding UTF8
} else {
    Write-Host "Baseline file not found: $baseline"
}

$result.HtmlPath
$result.JsonPath
