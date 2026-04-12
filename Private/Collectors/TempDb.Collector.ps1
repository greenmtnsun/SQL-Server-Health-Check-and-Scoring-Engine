
function Invoke-StsCollectorTempDb {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $warnCount = [int]$Context.Settings.TempDbFileCountWarn
    $q = @"
SELECT COUNT(*) AS file_count, SUM(size) * 8 / 1024 AS total_size_mb
FROM tempdb.sys.database_files
WHERE type_desc = 'ROWS';
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q -Database 'tempdb'
    $row = $rows | Select-Object -First 1

    $state = if ([int]$row.file_count -lt $warnCount) { 'Warning' } else { 'Info' }
    $msg = if ([int]$row.file_count -lt $warnCount) { 'TempDB data file count is below the warning threshold.' } else { 'TempDB layout inventoried.' }

    New-StsFinding -RunId $Context.RunId -Collector 'TempDb' -Category 'TempDb' -CheckId 'TEMPDB-FILES' -CheckName 'TempDB layout' `
        -TargetType 'Database' -TargetName 'tempdb' -InstanceName $Context.InstanceName -State $state -Severity 'Medium' -Weight 7 `
        -Message $msg -Evidence @{ FileCount = $row.file_count; TotalSizeMB = $row.total_size_mb; WarnThreshold = $warnCount } `
        -Recommendation 'Tune file count, size, and growth settings to match workload and contention profile.' -Source 'tsql'
}
