
function Invoke-StsCollectorHaDr {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $agQueueWarn = [int]$Context.Settings.AgQueueWarnKb
    $lsWarn = [int]$Context.Settings.LogShipLatencyWarnMinutes
    $out = New-Object System.Collections.Generic.List[object]

    $qAg = @"
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name AS ag_name,
        ar.replica_server_name,
        rs.role_desc,
        rs.connected_state_desc,
        rs.synchronization_health_desc,
        MAX(ISNULL(drs.log_send_queue_size,0)) AS log_send_queue_size,
        MAX(ISNULL(drs.redo_queue_size,0)) AS redo_queue_size
    FROM sys.availability_groups ag
    JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
    JOIN sys.dm_hadr_availability_replica_states rs ON ar.replica_id = rs.replica_id
    LEFT JOIN sys.dm_hadr_database_replica_states drs ON rs.replica_id = drs.replica_id
    GROUP BY ag.name, ar.replica_server_name, rs.role_desc, rs.connected_state_desc, rs.synchronization_health_desc;
END
"@
    $ag = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $qAg

    if ($ag) {
        foreach ($r in $ag) {
            $state = 'Healthy'
            if ($r.connected_state_desc -ne 'CONNECTED' -or $r.synchronization_health_desc -ne 'HEALTHY') {
                $state = 'Critical'
            } elseif ([int]$r.log_send_queue_size -gt $agQueueWarn -or [int]$r.redo_queue_size -gt $agQueueWarn) {
                $state = 'Warning'
            }

            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'HaDr' -Category 'AG' -CheckId 'AG-REPLICA-HEALTH' -CheckName 'AG replica health' `
                    -TargetType 'Replica' -TargetName ("{0}|{1}" -f $r.ag_name, $r.replica_server_name) -InstanceName $Context.InstanceName -State $state -Severity 'Critical' -Weight 10 `
                    -Message ("AG replica {0} is {1} / {2}." -f $r.replica_server_name, $r.connected_state_desc, $r.synchronization_health_desc) `
                    -Evidence @{ Role = $r.role_desc; Connected = $r.connected_state_desc; SyncHealth = $r.synchronization_health_desc; LogSendQueueKB = $r.log_send_queue_size; RedoQueueKB = $r.redo_queue_size; WarnQueueKB = $agQueueWarn } `
                    -Recommendation 'Investigate disconnected, unhealthy, or backlogged replicas.' -Source 'tsql')
            )
        }
    } else {
        $out.Add(
            (New-StsFinding -RunId $Context.RunId -Collector 'HaDr' -Category 'AG' -CheckId 'AG-REPLICA-HEALTH' -CheckName 'AG replica health' `
                -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Info' -Severity 'Info' -Weight 2 `
                -Message 'No AG replicas detected or HADR disabled.' -Evidence @{} -Recommendation 'None.' -Source 'tsql')
        )
    }

    try {
        $qLs = @"
SELECT COALESCE(p.primary_database, s.secondary_database) AS database_name, p.last_backup_date, s.last_restored_date, s.restore_threshold
FROM msdb.dbo.log_shipping_monitor_primary p
FULL OUTER JOIN msdb.dbo.log_shipping_monitor_secondary s ON p.primary_database = s.secondary_database;
"@
        $ls = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $qLs -Database msdb
        foreach ($r in @($ls)) {
            $state = 'Healthy'
            if ($r.last_restored_date -and (((Get-Date) - [datetime]$r.last_restored_date).TotalMinutes -gt $lsWarn)) {
                $state = 'Warning'
            }

            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'HaDr' -Category 'LogShipping' -CheckId 'LOGSHIP-STATUS' -CheckName 'Log shipping status' `
                    -TargetType 'Database' -TargetName $r.database_name -InstanceName $Context.InstanceName -State $state -Severity 'High' -Weight 8 `
                    -Message 'Log shipping monitor status collected.' -Evidence @{ LastBackup = $r.last_backup_date; LastRestore = $r.last_restored_date; RestoreThreshold = $r.restore_threshold; WarnMinutes = $lsWarn } `
                    -Recommendation 'Review backup, copy, and restore jobs if latency is persistent.' -Source 'tsql')
            )
        }
    } catch { }

    try {
        $qMir = @"
SELECT DB_NAME(database_id) AS database_name, mirroring_state_desc, mirroring_role_desc
FROM sys.database_mirroring
WHERE mirroring_guid IS NOT NULL;
"@
        $mir = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $qMir
        foreach ($r in @($mir)) {
            $state = if ($r.mirroring_state_desc -in @('SYNCHRONIZED','SYNCHRONIZING')) { 'Healthy' } else { 'Critical' }
            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'HaDr' -Category 'Mirroring' -CheckId 'MIRROR-STATE' -CheckName 'Database mirroring state' `
                    -TargetType 'Database' -TargetName $r.database_name -InstanceName $Context.InstanceName -State $state -Severity 'High' -Weight 7 `
                    -Message ("Mirroring state is {0}." -f $r.mirroring_state_desc) -Evidence @{ Role = $r.mirroring_role_desc } `
                    -Recommendation 'Investigate unhealthy mirroring states and plan retirement of legacy mirroring over time.' -Source 'tsql')
            )
        }
    } catch { }

    $out
}
