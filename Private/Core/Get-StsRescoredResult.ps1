function Get-StsRescoredResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Run,
        [Parameter(Mandatory)][object[]]$Findings,
        [Parameter(Mandatory)]$Settings
    )
    $stateScores = @{ Unknown=50; Info=100; Skipped=50; Critical=0; Warning=70; Healthy=100; Ignored=$null }
    $domainWeights = @{}
    if ($Settings -and $Settings.PSObject.Properties['DomainWeights']) {
        foreach ($p in $Settings.DomainWeights.PSObject.Properties) { $domainWeights[$p.Name] = [double]$p.Value }
    }

    $activeFindings = @($Findings | Where-Object State -ne 'Ignored')
    $collectors = @($Findings | Select-Object -ExpandProperty Collector -Unique | Sort-Object)
    $domainScores = foreach ($collector in $collectors) {
        $rows = @($activeFindings | Where-Object Collector -eq $collector)
        $weight = if ($domainWeights.ContainsKey($collector)) { [double]$domainWeights[$collector] } else { 1.0 }
        $score = 100.0
        if (@($rows).Count -gt 0) {
            $vals = foreach ($r in $rows) {
                if ($stateScores.ContainsKey([string]$r.State)) { [double]$stateScores[[string]$r.State] } else { 50.0 }
            }
            $score = [math]::Round((($vals | Measure-Object -Average).Average), 1)
        }
        [pscustomobject]@{ Collector=$collector; Score=$score; Coverage=100; Weight=$weight; Findings=@($rows).Count }
    }

    $weighted = 0.0; $weightSum = 0.0
    foreach ($d in @($domainScores)) { $weighted += ([double]$d.Score * [double]$d.Weight); $weightSum += [double]$d.Weight }
    $overall = if ($weightSum -gt 0) { [math]::Round(($weighted / $weightSum), 1) } else { 100.0 }

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
