function Invoke-SqlTechnicalSanity {
    param(
        [string]$SqlInstance,
        [string]$OutputDirectory,
        [switch]$PassThru
    )

    $findings = @()

    $findings += Invoke-StsCollectorInstance

    $score = Get-StsScores -Findings $findings

    $jsonPath = Join-Path $OutputDirectory "report.json"
    $htmlPath = Join-Path $OutputDirectory "report.html"

    $data = [pscustomobject]@{
        findings = $findings
        score = $score
    }

    $data | ConvertTo-Json -Depth 5 | Set-Content $jsonPath

    "<html><body><h1>Score: $($score.OverallScore)</h1></body></html>" | Set-Content $htmlPath

    if ($PassThru) {
        [pscustomobject]@{
            Score = $score
            JsonPath = $jsonPath
            HtmlPath = $htmlPath
        }
    }
}
