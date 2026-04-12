function Get-StsScores {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Findings,
        $Settings
    )

    if (-not $Settings) {
        $Settings = Get-StsSettings
    }

    $stateScores = $Settings.StateScores
    $domainWeights = $Settings.DomainWeights

    if (-not $stateScores) {
        throw "StateScores could not be loaded from settings."
    }

    if (-not $domainWeights) {
        $domainWeights = @{}
    }

    $activeFindings = @($Findings | Where-Object { $_.State -ne 'Ignored' })
    $collectors = @($Findings | Select-Object -ExpandProperty Collector -Unique | Sort-Object)

    $domainScores = foreach ($collector in $collectors) {
        $g = @($activeFindings | Where-Object Collector -eq $collector)
        $weight = if ($domainWeights.ContainsKey($collector)) { [double]$domainWeights[$collector] } else { 1.0 }

        $weightedActual = 0.0
        $weightedMax = 0.0
        $known = 0

        foreach ($f in $g) {
            if (-not $stateScores.ContainsKey([string]$f.State)) {
                continue
            }

            $stateScore = $stateScores[[string]$f.State]
            if ($null -eq $stateScore) {
                continue
            }

            $weightedActual += ([double]$f.Weight * [double]$stateScore)
            $weightedMax += [double]$f.Weight
            $known++
        }

        $score = 100.0
        if ($weightedMax -gt 0) {
            $score = [math]::Round(($weightedActual / $weightedMax) * 100, 1)
        }

        $coverage = 100.0
        if (@($g).Count -gt 0) {
            $coverage = [math]::Round(($known / @($g).Count) * 100, 1)
        }

        [pscustomobject]@{
            Collector = $collector
            Score     = $score
            Coverage  = $coverage
            Weight    = $weight
            Findings  = @($g).Count
        }
    }

    $weightedSum = 0.0
    $weightTotal = 0.0
    foreach ($d in @($domainScores)) {
        $weightedSum += ([double]$d.Score * [double]$d.Weight)
        $weightTotal += [double]$d.Weight
    }

    $overall = 100.0
    if ($weightTotal -gt 0) {
        $overall = [math]::Round(($weightedSum / $weightTotal), 1)
    }

    [pscustomobject]@{
        OverallScore  = $overall
        DomainScores  = @($domainScores)
        TotalFindings = @($Findings).Count
        CriticalCount = @($activeFindings | Where-Object State -eq 'Critical').Count
        WarningCount  = @($activeFindings | Where-Object State -eq 'Warning').Count
        UnknownCount  = @($activeFindings | Where-Object State -eq 'Unknown').Count
        HealthyCount  = @($activeFindings | Where-Object State -eq 'Healthy').Count
        InfoCount     = @($activeFindings | Where-Object State -eq 'Info').Count
        IgnoredCount  = @($Findings | Where-Object State -eq 'Ignored').Count
    }
}
