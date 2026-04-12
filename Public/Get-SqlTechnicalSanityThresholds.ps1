function Get-SqlTechnicalSanityThresholds {
    [CmdletBinding()]
    param(
        [hashtable]$Settings
    )

    $thresholds = @{}
    if ($Settings -and $Settings.ContainsKey('Thresholds')) {
        $thresholds = $Settings.Thresholds
    } elseif ($Settings) {
        $thresholds = $Settings
    }

    $fullHours = if ($thresholds.ContainsKey('FullBackupWarnHours')) { [double]$thresholds.FullBackupWarnHours } else { 30 }
    if ($thresholds.ContainsKey('FullBackupWarnDays')) {
        $fullHours = [double]$thresholds.FullBackupWarnDays * 24
    }

    $diffHours = if ($thresholds.ContainsKey('DiffBackupWarnHours')) { [double]$thresholds.DiffBackupWarnHours } else { 18 }
    if ($thresholds.ContainsKey('DiffBackupWarnDays')) {
        $diffHours = [double]$thresholds.DiffBackupWarnDays * 24
    }

    $logMinutes = if ($thresholds.ContainsKey('LogBackupWarnMinutes')) { [double]$thresholds.LogBackupWarnMinutes } else { 90 }
    if ($thresholds.ContainsKey('LogBackupWarnHours')) {
        $logMinutes = [double]$thresholds.LogBackupWarnHours * 60
    }

    [pscustomobject]@{
        FullBackupWarnHours  = [math]::Round($fullHours, 2)
        FullBackupWarnDays   = [math]::Round($fullHours / 24, 2)
        DiffBackupWarnHours  = [math]::Round($diffHours, 2)
        DiffBackupWarnDays   = [math]::Round($diffHours / 24, 2)
        LogBackupWarnMinutes = [math]::Round($logMinutes, 2)
        LogBackupWarnHours   = [math]::Round($logMinutes / 60, 2)
    }
}
