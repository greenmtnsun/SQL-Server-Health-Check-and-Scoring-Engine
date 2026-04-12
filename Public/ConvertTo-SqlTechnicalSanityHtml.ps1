function ConvertTo-SqlTechnicalSanityHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Run,
        [Parameter(Mandatory)][object[]]$Findings,
        [Parameter(Mandatory)]$Score,
        [string]$BaselineJsonPath
    )

    function Get-StateColor([string]$State) {
        switch ($State) {
            'Healthy'  { '#22c55e' }
            'Info'     { '#3b82f6' }
            'Warning'  { '#f59e0b' }
            'Critical' { '#ef4444' }
            'Ignored'  { '#6b7280' }
            default    { '#94a3b8' }
        }
    }

    function Get-ScoreClass([double]$Value) {
        if ($Value -ge 95) { 'good' }
        elseif ($Value -ge 85) { 'warn' }
        else { 'bad' }
    }

    $reportData = [pscustomobject]@{ run = $Run; score = $Score; findings = $Findings }
    $summary = Get-SqlTechnicalSanityExecutiveSummary -Data $reportData

    $actions = @()
    if (Get-Command Get-SqlTechnicalSanityTopActions -ErrorAction SilentlyContinue) {
        $actions = @(Get-SqlTechnicalSanityTopActions -Data $reportData -Top 3)
    }

    $baselineCompare = $null
    if (-not [string]::IsNullOrWhiteSpace($BaselineJsonPath)) {
        try {
            $tmpCurrent = Join-Path $env:TEMP ("sts-current-{0}.json" -f [guid]::NewGuid().Guid)
            ([pscustomobject]@{ run=$Run; score=$Score; findings=$Findings } | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $tmpCurrent -Encoding UTF8
            $baselineCompare = Compare-SqlTechnicalSanityBaseline -CurrentJsonPath $tmpCurrent -BaselineJsonPath $BaselineJsonPath
            Remove-Item -LiteralPath $tmpCurrent -ErrorAction SilentlyContinue
        } catch {
            $baselineCompare = $null
        }
    }

    $scoreDelta = 'n/a'
    $scoreDeltaClass = 'delta-flat'
    $warningDelta = 'baseline not supplied'
    $unknownDelta = ''
    $regressionCards = "<div class='summary-line'>No baseline comparison loaded.</div>"

    if ($baselineCompare -and $baselineCompare.Success) {
        if ($baselineCompare.ScoreDelta -gt 0) { $scoreDelta = "+$($baselineCompare.ScoreDelta)"; $scoreDeltaClass = 'delta-up' }
        elseif ($baselineCompare.ScoreDelta -lt 0) { $scoreDelta = "$($baselineCompare.ScoreDelta)"; $scoreDeltaClass = 'delta-down' }
        else { $scoreDelta = '0'; $scoreDeltaClass = 'delta-flat' }

        $wd = ([int]$baselineCompare.CurrentWarnings - [int]$baselineCompare.BaselineWarnings)
        $ud = ([int]$baselineCompare.CurrentUnknown - [int]$baselineCompare.BaselineUnknown)

        if ($wd -gt 0) { $warningDelta = "+$wd warning(s)" }
        elseif ($wd -lt 0) { $warningDelta = "$wd warning(s)" }
        else { $warningDelta = '0 warning delta' }

        if ($ud -gt 0) { $unknownDelta = "+$ud unknown(s)" }
        elseif ($ud -lt 0) { $unknownDelta = "$ud unknown(s)" }
        else { $unknownDelta = '0 unknown delta' }

        if (@($baselineCompare.TopRegressions).Count -gt 0) {
            $regressionParts = foreach ($r in @($baselineCompare.TopRegressions)) {
                "<div class='mini-regression'><span>$($r.Collector)</span><span class='mono delta-down'>$($r.Delta)</span></div>"
            }
            $regressionCards = ($regressionParts -join "`n")
        } else {
            $regressionCards = "<div class='summary-line'>No domain regressions against baseline.</div>"
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($BaselineJsonPath)) {
        $warningDelta = 'baseline compare unavailable'
        $regressionCards = "<div class='summary-line'>Baseline compare unavailable.</div>"
    }

    $domainRows = foreach ($d in @($Score.DomainScores | Sort-Object Score, Collector)) {
        $deltaText = 'n/a'
        $deltaClass = 'delta-flat'
        if ($baselineCompare -and $baselineCompare.Success) {
            $match = @($baselineCompare.DomainDelta | Where-Object Collector -eq $d.Collector | Select-Object -First 1)
            if ($match) {
                if ($match.Delta -gt 0) { $deltaText = "+$($match.Delta)"; $deltaClass = 'delta-up' }
                elseif ($match.Delta -lt 0) { $deltaText = "$($match.Delta)"; $deltaClass = 'delta-down' }
                else { $deltaText = '0'; $deltaClass = 'delta-flat' }
            }
        }
        "<tr><td>$($d.Collector)</td><td><div class='meter'><div class='fill $(Get-ScoreClass([double]$d.Score))' style='width:$([math]::Round([double]$d.Score,0))%;'></div></div></td><td class='mono score-$(Get-ScoreClass([double]$d.Score))'>$($d.Score)</td><td class='mono'>$($d.Coverage)%</td><td class='mono'>$($d.Findings)</td><td class='mono $deltaClass'>$deltaText</td></tr>"
    }

    $actionCards = if (@($actions).Count -gt 0) {
        foreach ($a in @($actions)) {
            "<div class='action-item'><div class='action-title'>$($a.CheckId) &middot; $([System.Net.WebUtility]::HtmlEncode([string]$a.TargetName))</div><div class='action-msg'>$([System.Net.WebUtility]::HtmlEncode([string]$a.Message))</div><div class='action-rec'>$([System.Net.WebUtility]::HtmlEncode([string]$a.Recommendation))</div></div>"
        }
    } else {
        @("<div class='action-item'><div class='action-title'>No prioritized actions available</div><div class='action-msg'>The action engine did not return any ranked findings.</div><div class='action-rec'>Confirm helper functions are loaded and the run contains actionable findings.</div></div>")
    }

    $ignoredFindings = @($Findings | Where-Object State -eq 'Ignored')
    $ignoredCards = if (@($ignoredFindings).Count -gt 0) {
        foreach ($f in $ignoredFindings) {
            "<div class='action-item'><div class='action-title'>$($f.CheckId) &middot; $([System.Net.WebUtility]::HtmlEncode([string]$f.TargetName))</div><div class='action-msg'>$([System.Net.WebUtility]::HtmlEncode([string]$f.IgnoreReason))</div><div class='action-rec'>Owner: $([System.Net.WebUtility]::HtmlEncode([string]$f.IgnoreOwner))  Expires: $([System.Net.WebUtility]::HtmlEncode([string]$f.IgnoreExpires))</div></div>"
        }
    } else {
        @("<div class='action-item'><div class='action-title'>No ignored findings</div><div class='action-msg'>Nothing is currently suppressed by policy.</div><div class='action-rec'>Use Invoke-SqlTechnicalSanityWithPolicy with an IgnoreRules psd1 file to suppress accepted signal.</div></div>")
    }

    $infraLines = @()
    $ag = @($Findings | Where-Object CheckId -eq 'AG-DB-SYNC' | Select-Object -First 1)
    $cluster = @($Findings | Where-Object CheckId -eq 'CLUSTER-BALANCE' | Select-Object -First 1)
    $repl = @($Findings | Where-Object CheckId -eq 'REPL-SUMMARY' | Select-Object -First 1)
    if ($cluster) { $infraLines += "Cluster: $($cluster[0].Message)" }
    if ($ag) { $infraLines += "AG: $($ag[0].Message)" }
    if ($repl) { $infraLines += "Replication: $($repl[0].Message)" }
    if ($infraLines.Count -eq 0) { $infraLines += 'No infrastructure-specific findings surfaced.' }
    $infraCards = foreach ($line in $infraLines) { "<div class='summary-line'>$([System.Net.WebUtility]::HtmlEncode([string]$line))</div>" }

    $topFindings = @($Findings | Where-Object State -ne 'Ignored' | Sort-Object @{Expression={switch ($_.State) {'Critical' {1} 'Warning' {2} 'Unknown' {3} 'Info' {8} default {9}}}}, Collector, TargetName | Select-Object -First 10)
    $findingCards = foreach ($f in $topFindings) {
        $stateColor = Get-StateColor $f.State
        $evidence = (($f.Evidence.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join '; ')
        "<div class='finding-card'><div class='finding-head'><span class='pill' style='background:$stateColor;'>$($f.State)</span><span class='finding-check'>$($f.CheckId)</span><span class='finding-target'>$([System.Net.WebUtility]::HtmlEncode([string]$f.TargetName))</span></div><div class='finding-msg'>$([System.Net.WebUtility]::HtmlEncode([string]$f.Message))</div><div class='finding-evidence'>$([System.Net.WebUtility]::HtmlEncode([string]$evidence))</div></div>"
    }

    $summaryList = foreach ($line in @($summary.Summary)) { "<div class='summary-line'>$([System.Net.WebUtility]::HtmlEncode([string]$line))</div>" }

@"
<!doctype html><html><head><meta charset='utf-8'><title>SqlTechnicalSanity Report</title><style>
body{margin:0;background:#0f172a;color:#e5e7eb;font-family:Segoe UI,Arial,sans-serif}.page{max-width:1480px;margin:0 auto;padding:24px}.hero{background:linear-gradient(135deg,#111827 0%,#1f2937 100%);border:1px solid #334155;border-radius:22px;padding:26px;box-shadow:0 24px 54px rgba(0,0,0,.28)}.title{font-size:32px;font-weight:900}.sub{margin-top:8px;color:#94a3b8}.grid{display:grid;grid-template-columns:1.2fr .8fr .8fr .8fr;gap:16px;margin-top:20px}.card{background:#111827;border:1px solid #334155;border-radius:18px;padding:18px;box-shadow:0 12px 28px rgba(0,0,0,.2)}.label{font-size:12px;color:#94a3b8;text-transform:uppercase;letter-spacing:.08em}.big{font-size:42px;font-weight:900;margin-top:8px}.good{color:#22c55e}.warn{color:#f59e0b}.bad{color:#ef4444}.summary-line{padding:8px 0;border-bottom:1px solid #1f2937;color:#dbeafe}.kpis{display:grid;grid-template-columns:repeat(5,1fr);gap:12px}.kpi{background:#0b1220;border:1px solid #1f2937;border-radius:14px;padding:12px}.kpi .k{font-size:11px;color:#94a3b8;text-transform:uppercase}.kpi .v{font-size:24px;font-weight:800;margin-top:6px}.section{display:grid;grid-template-columns:1.05fr .95fr;gap:16px;margin-top:20px}.table-wrap,.panel{background:#111827;border:1px solid #334155;border-radius:18px;overflow:hidden;box-shadow:0 12px 28px rgba(0,0,0,.2)}.panel{padding:18px;overflow:visible}.panel-title{font-size:16px;font-weight:800;margin-bottom:10px}table{width:100%;border-collapse:collapse}th{padding:12px;background:#0b1220;color:#cbd5e1;text-align:left;font-size:12px;text-transform:uppercase;letter-spacing:.08em}td{padding:12px;border-bottom:1px solid #1f2937;font-size:13px}tr:hover td{background:#0b1220}.meter{height:10px;border-radius:999px;background:#1f2937;overflow:hidden}.fill{height:10px}.fill.good{background:#22c55e}.fill.warn{background:#f59e0b}.fill.bad{background:#ef4444}.mono{font-family:Consolas,monospace}.score-good{color:#22c55e;font-weight:800}.score-warn{color:#f59e0b;font-weight:800}.score-bad{color:#ef4444;font-weight:800}.delta-up{color:#22c55e;font-weight:800}.delta-down{color:#ef4444;font-weight:800}.delta-flat{color:#94a3b8;font-weight:800}.findings-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:18px}.finding-card,.action-item{background:#111827;border:1px solid #334155;border-radius:18px;padding:16px;box-shadow:0 12px 28px rgba(0,0,0,.2)}.finding-head{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.pill{display:inline-block;padding:4px 10px;border-radius:999px;color:#fff;font-size:11px;font-weight:800}.finding-check{font-family:Consolas,monospace;font-size:12px;color:#93c5fd}.finding-target{font-weight:700}.finding-msg,.action-msg{margin-top:10px;font-size:14px}.action-title{font-weight:800}.finding-evidence,.action-rec{margin-top:10px;color:#94a3b8;font-family:Consolas,monospace;font-size:11px;overflow-wrap:anywhere}.mini-regression{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #1f2937}.footer{margin-top:16px;color:#64748b;font-size:12px}@media (max-width:1200px){.grid{grid-template-columns:1fr 1fr}.section{grid-template-columns:1fr}.findings-grid{grid-template-columns:1fr}.kpis{grid-template-columns:repeat(3,1fr)}}
</style></head><body><div class='page'><div class='hero'><div class='title'>SqlTechnicalSanity</div><div class='sub'>Instances: $($Run.Instances -join ', ') &middot; RunId: $($Run.RunId) &middot; Generated: $($Run.GeneratedAt) &middot; Host: $($Run.HostName) &middot; dbatools: $($Run.DbatoolsVersion)</div><div class='grid'><div class='card'><div class='label'>Executive summary</div><div class='big $(Get-ScoreClass([double]$Score.OverallScore))'>$($Score.OverallScore)<span style='font-size:16px;color:#94a3b8'>/100</span></div>$($summaryList -join "`n")</div><div class='card'><div class='label'>Delta vs baseline</div><div class='big $scoreDeltaClass'>$scoreDelta</div><div class='summary-line'>$warningDelta</div><div class='summary-line'>$unknownDelta</div></div><div class='card'><div class='label'>Signal mix</div><div class='kpis'><div class='kpi'><div class='k'>Critical</div><div class='v bad'>$($Score.CriticalCount)</div></div><div class='kpi'><div class='k'>Warning</div><div class='v warn'>$($Score.WarningCount)</div></div><div class='kpi'><div class='k'>Unknown</div><div class='v'>$($Score.UnknownCount)</div></div><div class='kpi'><div class='k'>Healthy</div><div class='v good'>$($Score.HealthyCount)</div></div><div class='kpi'><div class='k'>Ignored</div><div class='v'>$($(if ($Score.PSObject.Properties['IgnoredCount']) { $Score.IgnoredCount } else { 0 }))</div></div></div></div><div class='card'><div class='label'>Top regressions</div>$regressionCards</div></div></div><div class='section'><div class='table-wrap'><table><tr><th>Domain</th><th>Meter</th><th>Score</th><th>Coverage</th><th>Findings</th><th>&Delta;</th></tr>$($domainRows -join "`n")</table></div><div class='panel'><div class='panel-title'>Top actions</div>$($actionCards -join "`n")<div class='panel-title' style='margin-top:14px'>Infrastructure health</div>$($infraCards -join "`n")</div></div><div class='section'><div class='panel'><div class='panel-title'>Ignored findings</div>$($ignoredCards -join "`n")</div><div class='panel'><div class='panel-title'>Policy note</div><div class='summary-line'>Ignored findings are detected, retained, and shown, but excluded from score and top-actions ranking.</div><div class='summary-line'>Use Config\IgnoreRules.psd1 or your own policy file with Invoke-SqlTechnicalSanityWithPolicy.</div></div></div><div class='findings-grid'>$($findingCards -join "`n")</div><div class='footer'>v6.7.1 parser fix: policy-based suppression, rescoring, baseline-safe rendering, and ignored findings visibility.</div></div></body></html>
"@
}
