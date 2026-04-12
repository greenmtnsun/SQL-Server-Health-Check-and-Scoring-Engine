function Compare-SqlTechnicalSanityBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CurrentJsonPath,
        [Parameter(Mandatory)][string]$BaselineJsonPath
    )
    if (-not (Test-Path -LiteralPath $CurrentJsonPath)) { throw "Current JSON path not found: $CurrentJsonPath" }
    if (-not (Test-Path -LiteralPath $BaselineJsonPath)) {
        return [pscustomobject]@{ CurrentRunId=$null; BaselineRunId=$null; CurrentScore=$null; BaselineScore=$null; ScoreDelta=$null; CurrentWarnings=$null; BaselineWarnings=$null; CurrentUnknown=$null; BaselineUnknown=$null; DomainDelta=@(); TopRegressions=@(); Success=$false; Error="Baseline JSON path not found: $BaselineJsonPath" }
    }
    $current = Get-Content -LiteralPath $CurrentJsonPath -Raw | ConvertFrom-Json
    $baseline = Get-Content -LiteralPath $BaselineJsonPath -Raw | ConvertFrom-Json
    if (-not $current.PSObject.Properties['score'] -or -not $current.PSObject.Properties['run']) { throw "Current JSON does not have expected run/score structure: $CurrentJsonPath" }
    if (-not $baseline.PSObject.Properties['score'] -or -not $baseline.PSObject.Properties['run']) {
        return [pscustomobject]@{ CurrentRunId=$current.run.RunId; BaselineRunId=$null; CurrentScore=[double]$current.score.OverallScore; BaselineScore=$null; ScoreDelta=$null; CurrentWarnings=[int]$current.score.WarningCount; BaselineWarnings=$null; CurrentUnknown=[int]$current.score.UnknownCount; BaselineUnknown=$null; DomainDelta=@(); TopRegressions=@(); Success=$false; Error="Baseline JSON does not have expected run/score structure: $BaselineJsonPath" }
    }
    $currDomains = @{}; foreach ($d in @($current.score.DomainScores)) { $currDomains[$d.Collector] = $d }
    $baseDomains = @{}; foreach ($d in @($baseline.score.DomainScores)) { $baseDomains[$d.Collector] = $d }
    $allDomains = @($currDomains.Keys + $baseDomains.Keys | Sort-Object -Unique)
    $domainDelta = foreach ($name in $allDomains) {
        $c = $currDomains[$name]; $b = $baseDomains[$name]
        $currentScore = $null; if ($c) { $currentScore = [double]$c.Score }
        $baselineScore = $null; if ($b) { $baselineScore = [double]$b.Score }
        $delta = $null; if ($c -and $b) { $delta = [math]::Round(([double]$c.Score - [double]$b.Score), 1) }
        $currentFindings = $null; if ($c) { $currentFindings = [int]$c.Findings }
        $baselineFindings = $null; if ($b) { $baselineFindings = [int]$b.Findings }
        [pscustomobject]@{
            Collector = $name; CurrentScore = $currentScore; BaselineScore = $baselineScore; Delta = $delta; CurrentFindings = $currentFindings; BaselineFindings = $baselineFindings
        }
    }
    $regressions = @($domainDelta | Where-Object { $null -ne $_.Delta -and $_.Delta -lt 0 } | Sort-Object Delta, Collector | Select-Object -First 5)
    [pscustomobject]@{
        CurrentRunId = $current.run.RunId
        BaselineRunId = $baseline.run.RunId
        CurrentScore = [double]$current.score.OverallScore
        BaselineScore = [double]$baseline.score.OverallScore
        ScoreDelta = [math]::Round(([double]$current.score.OverallScore - [double]$baseline.score.OverallScore), 1)
        CurrentWarnings = [int]$current.score.WarningCount
        BaselineWarnings = [int]$baseline.score.WarningCount
        CurrentUnknown = [int]$current.score.UnknownCount
        BaselineUnknown = [int]$baseline.score.UnknownCount
        DomainDelta = $domainDelta
        TopRegressions = $regressions
        Success = $true
        Error = $null
    }
}
