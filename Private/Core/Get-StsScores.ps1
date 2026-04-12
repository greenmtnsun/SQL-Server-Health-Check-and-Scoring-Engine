function Get-StsScores {
    param($Findings)

    $scores = Import-PowerShellDataFile "$PSScriptRoot\..\..\Config\Defaults.psd1"

    $stateScores = $scores.StateScores

    $total = 0
    $max = 0

    foreach ($f in $Findings) {
        $total += $stateScores[$f.State]
        $max += 1
    }

    $overall = if ($max -gt 0) { [math]::Round(($total / $max)*100,1) } else { 100 }

    [pscustomobject]@{
        OverallScore = $overall
    }
}
