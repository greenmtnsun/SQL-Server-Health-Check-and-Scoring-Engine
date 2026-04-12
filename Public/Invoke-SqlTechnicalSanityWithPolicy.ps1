function Invoke-SqlTechnicalSanityWithPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SqlInstance,
        [string]$OutputDirectory = '.',
        [string]$IgnoreRulesPath,
        [string]$BaselineJsonPath,
        $SqlCredential,
        [switch]$PassThru
    )

    $result = Invoke-SqlTechnicalSanity -SqlInstance $SqlInstance -OutputDirectory $OutputDirectory -SqlCredential $SqlCredential -PassThru
    if (-not $result) { return }

    $jsonPath = $result.JsonPath
    $htmlPath = $result.HtmlPath
    $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json

    $ignoreConfig = $null
    if (-not [string]::IsNullOrWhiteSpace($IgnoreRulesPath) -and (Test-Path -LiteralPath $IgnoreRulesPath)) {
        $ignoreConfig = Import-PowerShellDataFile -LiteralPath $IgnoreRulesPath
    }

    if ($ignoreConfig) {
        $newFindings = Apply-StsIgnoreRules -Findings @($data.findings) -IgnoreConfig $ignoreConfig
        $newScore = Get-StsRescoredResult -Run $data.run -Findings $newFindings -Settings $data.run.Settings
        $data.findings = @($newFindings)
        $data.score = $newScore
    }

    $jsonOut = $data | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $jsonPath -Value $jsonOut -Encoding UTF8

    $html = ConvertTo-SqlTechnicalSanityHtml -Run $data.run -Findings @($data.findings) -Score $data.score -BaselineJsonPath $BaselineJsonPath
    Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8

    $out = [pscustomobject]@{ HtmlPath=$htmlPath; JsonPath=$jsonPath; RunId=$data.run.RunId; Score=$data.score }
    if ($PassThru) { $out } else { $out | Select-Object HtmlPath, JsonPath, RunId }
}
