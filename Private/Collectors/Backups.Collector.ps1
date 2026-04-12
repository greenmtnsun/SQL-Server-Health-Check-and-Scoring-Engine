
function Invoke-StsCollectorBackups {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $warnFull = [int]$Context.Settings.FullBackupWarnHours
    $warnLog = [int]$Context.Settings.LogBackupWarnMinutes

    $q = @"
SELECT
    d.name,
    d.state_desc,
    d.recovery_model_desc,
    d.source_database_id,
    MAX(CASE WHEN b.type='D' THEN b.backup_finish_date END) AS last_full_backup,
    MAX(CASE WHEN b.type='I' THEN b.backup_finish_date END) AS last_diff_backup,
    MAX(CASE WHEN b.type='L' THEN b.backup_finish_date END) AS last_log_backup
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b ON b.database_name = d.name
GROUP BY d.name, d.state_desc, d.recovery_model_desc, d.source_database_id
ORDER BY d.name;
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q -Database msdb

    foreach ($db in $rows) {
        if ($db.name -eq 'tempdb') { continue }
        if ($db.state_desc -ne 'ONLINE') { continue }
        if ($db.source_database_id) { continue }

        $fullState = 'Healthy'
        $fullMsg = 'Full backup freshness is good.'
        if (-not $db.last_full_backup) {
            $fullState = 'Critical'
            $fullMsg = 'No full backup found.'
        } elseif (((Get-Date) - [datetime]$db.last_full_backup).TotalHours -gt $warnFull) {
            $fullState = 'Warning'
            $fullMsg = 'Full backup is older than threshold.'
        }

        New-StsFinding -RunId $Context.RunId -Collector 'Backups' -Category 'Backups' -CheckId 'BACKUP-LAST-FULL' -CheckName 'Full backup freshness' `
            -TargetType 'Database' -TargetName $db.name -InstanceName $Context.InstanceName -State $fullState -Severity 'High' -Weight 10 `
            -Message $fullMsg -Evidence @{ LastFullBackup = $db.last_full_backup; LastDiffBackup = $db.last_diff_backup; WarnHours = $warnFull; RecoveryModel = $db.recovery_model_desc } `
            -Recommendation 'Confirm successful full backup cadence.' -Source 'tsql'

        if ($db.recovery_model_desc -eq 'FULL') {
            $logState = 'Healthy'
            $logMsg = 'Log backup freshness is good.'
            if (-not $db.last_log_backup) {
                $logState = 'Critical'
                $logMsg = 'No log backup found for FULL recovery database.'
            } elseif (((Get-Date) - [datetime]$db.last_log_backup).TotalMinutes -gt $warnLog) {
                $logState = 'Warning'
                $logMsg = 'Log backup is older than threshold.'
            }

            New-StsFinding -RunId $Context.RunId -Collector 'Backups' -Category 'Backups' -CheckId 'BACKUP-LAST-LOG' -CheckName 'Log backup freshness' `
                -TargetType 'Database' -TargetName $db.name -InstanceName $Context.InstanceName -State $logState -Severity 'Critical' -Weight 10 `
                -Message $logMsg -Evidence @{ LastLogBackup = $db.last_log_backup; WarnMinutes = $warnLog } `
                -Recommendation 'Fix log backup schedule or confirm recovery model intent.' -Source 'tsql'
        }
    }
}
