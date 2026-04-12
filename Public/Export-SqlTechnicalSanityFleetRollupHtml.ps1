function Export-SqlTechnicalSanityFleetRollupHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$FleetRows,
        [Parameter(Mandatory)][string]$OutputPath
    )

    $rows = @($FleetRows)

    $groups = $rows |
        Group-Object HostName, Instances |
        ForEach-Object {
            $ordered = $_.Group | Sort-Object GeneratedAt
            $latest = $ordered | Select-Object -Last 1
            $worst = $ordered |
                Sort-Object `
                    @{Expression='OverallScore';Descending=$false}, `
                    @{Expression='CriticalCount';Descending=$true} |
                Select-Object -First 1

            $first = $ordered | Select-Object -First 1
            $last = $ordered | Select-Object -Last 1

            $trend = 'stable'
            if ($first.OverallScore -lt $last.OverallScore) { $trend = 'improving' }
            elseif ($first.OverallScore -gt $last.OverallScore) { $trend = 'degrading' }

            $scores = @($ordered | ForEach-Object { [double]$_.OverallScore })
            $avg = 0
            if ($scores.Count -gt 0) { $avg = ($scores | Measure-Object -Average).Average }

            $variance = 0
            foreach ($s in $scores) {
                $variance += [math]::Pow(($s - $avg), 2)
            }

            $stdev = 0
            if ($scores.Count -gt 1) {
                $stdev = [math]::Sqrt($variance / $scores.Count)
            }

            $volatility = 'low'
            if ($stdev -ge 4) { $volatility = 'high' }
            elseif ($stdev -ge 1.5) { $volatility = 'medium' }

            [pscustomobject]@{
                HostName          = $latest.HostName
                Instances         = $latest.Instances
                LatestScore       = $latest.OverallScore
                LatestWarnings    = $latest.WarningCount
                LatestCritical    = $latest.CriticalCount
                LatestUnknown     = $latest.UnknownCount
                LatestGeneratedAt = $latest.GeneratedAt
                LatestFile        = $latest.File
                WorstScore        = $worst.OverallScore
                RunCount          = @($ordered).Count
                Trend             = $trend
                Volatility        = $volatility
            }
        } |
        Sort-Object `
            @{Expression='LatestScore';Descending=$true}, `
            @{Expression='LatestCritical';Descending=$false}, `
            @{Expression='LatestWarnings';Descending=$false}, `
            @{Expression='LatestUnknown';Descending=$false}, `
            @{Expression='HostName';Descending=$false}

    $riskLines = foreach ($g in $groups) {
        $notes = @()
        if ($g.WorstScore -lt 90) { $notes += "historical instability" }
        if ($g.LatestWarnings -gt 0) { $notes += "$($g.LatestWarnings) warning(s) in latest run" }
        if ($g.LatestCritical -gt 0) { $notes += "$($g.LatestCritical) critical finding(s)" }
        if ($g.Volatility -eq 'high') { $notes += "high score volatility" }

        if ($notes.Count -gt 0) {
            "<div class='risk-item'><span class='risk-host'>$($g.HostName)</span><span class='risk-note'>$([string]::Join('; ', $notes))</span></div>"
        }
    }

    $best = $groups | Select-Object -First 5
    $worst = $groups |
        Sort-Object `
            @{Expression='LatestScore';Descending=$false}, `
            @{Expression='LatestCritical';Descending=$true} |
        Select-Object -First 5

    function New-Mini([object[]]$items) {
        $parts = foreach ($i in $items) {
            "<div class='mini-item'><span class='mini-host'>$($i.HostName)</span><span class='mini-score'>$($i.LatestScore)</span><span class='mini-file'>$($i.Trend) / $($i.Volatility) / $($i.RunCount) run(s)</span></div>"
        }
        $parts -join "`n"
    }

    $tableRows = foreach ($g in $groups) {
        "<tr><td class='mono'>$($g.HostName)</td><td>$($g.Instances)</td><td class='mono'>$($g.LatestScore)</td><td>$($g.Trend)</td><td>$($g.Volatility)</td><td class='mono'>$($g.LatestCritical)</td><td class='mono'>$($g.LatestWarnings)</td><td class='mono'>$($g.RunCount)</td><td class='mono'>$($g.LatestGeneratedAt)</td><td class='mono'>$($g.LatestFile)</td></tr>"
    }

    $riskBlock = if (@($riskLines).Count -gt 0) {
        $riskLines -join "`n"
    } else {
        "<div class='risk-item'><span class='risk-note'>No fleet risks surfaced from the currently loaded history.</span></div>"
    }

    $html = @"
<!doctype html><html><head><meta charset='utf-8'><title>SqlTechnicalSanity Fleet Rollup</title><style>
body{margin:0;background:#0f172a;color:#e5e7eb;font-family:Segoe UI,Arial,sans-serif}.page{max-width:1480px;margin:0 auto;padding:24px}.hero{background:linear-gradient(135deg,#111827 0%,#1f2937 100%);border:1px solid #334155;border-radius:20px;padding:24px;box-shadow:0 20px 40px rgba(0,0,0,.25)}.title{font-size:30px;font-weight:800}.subtitle{color:#94a3b8;margin-top:8px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-top:20px}.card{background:#111827;border:1px solid #334155;border-radius:18px;padding:18px;box-shadow:0 12px 28px rgba(0,0,0,.2)}.label{color:#94a3b8;font-size:12px;text-transform:uppercase;letter-spacing:.08em}.value{font-size:30px;font-weight:800;margin-top:6px}.good{color:#22c55e}.warn{color:#f59e0b}.bad{color:#ef4444}.section{margin-top:22px;display:grid;grid-template-columns:1fr 1fr;gap:16px}.mini-item,.risk-item{display:grid;grid-template-columns:1fr auto 1.4fr;gap:10px;padding:10px 0;border-bottom:1px solid #1f2937}.risk-item{grid-template-columns:.9fr 2.1fr}.mini-host,.risk-host{font-weight:700}.mini-score{font-family:Consolas,monospace}.mini-file,.risk-note{color:#94a3b8;font-size:12px;overflow-wrap:anywhere}.table-wrap{margin-top:22px;background:#111827;border:1px solid #334155;border-radius:18px;overflow:hidden;box-shadow:0 12px 28px rgba(0,0,0,.2)}table{width:100%;border-collapse:collapse}th{text-align:left;background:#0b1220;color:#cbd5e1;font-size:12px;text-transform:uppercase;letter-spacing:.08em;padding:12px}td{padding:12px;border-bottom:1px solid #1f2937;font-size:13px}tr:hover td{background:#0b1220}.mono{font-family:Consolas,monospace}.footer{color:#64748b;font-size:12px;margin-top:16px}@media (max-width:1100px){.grid{grid-template-columns:repeat(2,1fr)}.section{grid-template-columns:1fr}}
</style></head><body><div class='page'><div class='hero'><div class='title'>SqlTechnicalSanity Fleet Rollup</div><div class='subtitle'>Deduped by host + instance. Trends, volatility, and risk notes replace duplicate-run noise.</div><div class='grid'><div class='card'><div class='label'>Host+Instance Sets</div><div class='value'>$(@($groups).Count)</div></div><div class='card'><div class='label'>Best Latest Score</div><div class='value good'>$((($groups | Measure-Object LatestScore -Maximum).Maximum))</div></div><div class='card'><div class='label'>Worst Historical Score</div><div class='value bad'>$((($groups | Measure-Object WorstScore -Minimum).Minimum))</div></div><div class='card'><div class='label'>Average Latest Score</div><div class='value warn'>$([math]::Round((($groups | Measure-Object LatestScore -Average).Average),1))</div></div></div><div class='section'><div class='card'><div class='label'>Best Current Sets</div>$(New-Mini $best)</div><div class='card'><div class='label'>Worst Current Sets</div>$(New-Mini $worst)</div></div><div class='section'><div class='card'><div class='label'>Fleet Risks</div>$riskBlock</div><div class='card'><div class='label'>How to read this</div><div class='risk-item'><span class='risk-note'>Trend shows first-to-latest movement across historical reports. Volatility is score standard deviation. Table shows latest state per host+instance.</span></div></div></div></div><div class='table-wrap'><table><tr><th>Host</th><th>Instances</th><th>Latest Score</th><th>Trend</th><th>Volatility</th><th>Critical</th><th>Warning</th><th>Runs</th><th>Latest Generated</th><th>Latest File</th></tr>$($tableRows -join "`n")</table></div><div class='footer'>v6.6 fleet signal layer: deduped rows, trend, volatility, and current-state ranking.</div></div></body></html>
"@

    [System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.Encoding]::UTF8)
    Get-Item -LiteralPath $OutputPath
}
