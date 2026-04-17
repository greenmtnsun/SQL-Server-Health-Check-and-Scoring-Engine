# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Compare-SqlTechnicalSanityBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CurrentJsonPath,
        [Parameter(Mandatory)][string]$BaselineJsonPath
    )

    if (-not (Test-Path -LiteralPath $CurrentJsonPath)) {
        throw "Current JSON path not found: $CurrentJsonPath"
    }

    if (-not (Test-Path -LiteralPath $BaselineJsonPath)) {
        throw "Baseline JSON path not found: $BaselineJsonPath"
    }

    try {
        $current = Get-Content -LiteralPath $CurrentJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            CurrentRunId      = $null
            BaselineRunId     = $null
            CurrentScore      = $null
            BaselineScore     = $null
            ScoreDelta        = $null
            CurrentWarnings   = $null
            BaselineWarnings  = $null
            CurrentUnknown    = $null
            BaselineUnknown   = $null
            DomainDelta       = @()
            TopRegressions    = @()
            Success           = $false
            Error             = "Failed to parse current JSON: $($_.Exception.Message)"
        }
    }

    try {
        $baseline = Get-Content -LiteralPath $BaselineJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            CurrentRunId      = $null
            BaselineRunId     = $null
            CurrentScore      = $null
            BaselineScore     = $null
            ScoreDelta        = $null
            CurrentWarnings   = $null
            BaselineWarnings  = $null
            CurrentUnknown    = $null
            BaselineUnknown   = $null
            DomainDelta       = @()
            TopRegressions    = @()
            Success           = $false
            Error             = "Failed to parse baseline JSON: $($_.Exception.Message)"
        }
    }

    $currentDomains = @{}
    foreach ($d in @($current.score.DomainScores)) { $currentDomains[[string]$d.Collector] = $d }
    $baselineDomains = @{}
    foreach ($d in @($baseline.score.DomainScores)) { $baselineDomains[[string]$d.Collector] = $d }

    $allCollectors = @(($currentDomains.Keys + $baselineDomains.Keys) | Sort-Object -Unique)

    $domainDelta = foreach ($collector in $allCollectors) {
        $c = if ($currentDomains.ContainsKey($collector)) { $currentDomains[$collector] } else { $null }
        $b = if ($baselineDomains.ContainsKey($collector)) { $baselineDomains[$collector] } else { $null }

        $currentScore = if ($c -and $null -ne $c.Score) { [double]$c.Score } else { 0 }
        $baselineScore = if ($b -and $null -ne $b.Score) { [double]$b.Score } else { 0 }
        $currentFindings = if ($c -and $null -ne $c.Findings) { [int]$c.Findings } else { 0 }
        $baselineFindings = if ($b -and $null -ne $b.Findings) { [int]$b.Findings } else { 0 }

        [pscustomobject]@{
            Collector        = $collector
            CurrentScore     = $currentScore
            BaselineScore    = $baselineScore
            Delta            = [math]::Round(($currentScore - $baselineScore), 1)
            CurrentFindings  = $currentFindings
            BaselineFindings = $baselineFindings
        }
    }

    $regressions = @(
        $domainDelta |
        Where-Object { $_.Delta -lt 0 } |
        Sort-Object Delta, Collector |
        Select-Object -First 5
    )

    [pscustomobject]@{
        CurrentRunId      = $current.run.RunId
        BaselineRunId     = $baseline.run.RunId
        CurrentScore      = [double]$current.score.OverallScore
        BaselineScore     = [double]$baseline.score.OverallScore
        ScoreDelta        = [math]::Round(([double]$current.score.OverallScore - [double]$baseline.score.OverallScore), 1)
        CurrentWarnings   = [int]$current.score.WarningCount
        BaselineWarnings  = [int]$baseline.score.WarningCount
        CurrentUnknown    = [int]$current.score.UnknownCount
        BaselineUnknown   = [int]$baseline.score.UnknownCount
        DomainDelta       = @($domainDelta)
        TopRegressions    = @($regressions)
        Success           = $true
        Error             = $null
    }
}
