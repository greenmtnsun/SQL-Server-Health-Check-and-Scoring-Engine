
function Invoke-StsCollectorAgIntelligence {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $redoWarn = [int]$Context.Settings.AgDbRedoQueueWarnKb
    $sendWarn = [int]$Context.Settings.AgDbSendQueueWarnKb
    $primarySkewWarn = [int]$Context.Settings.AgPrimarySkewWarnCount

    $out = New-Object System.Collections.Generic.List[object]

    $q = @"
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    ;WITH core AS (
        SELECT
            ag.name AS ag_name,
            ar.replica_server_name,
            ars.role_desc,
            ars.connected_state_desc,
            ars.synchronization_health_desc,
            DB_NAME(drs.database_id) AS database_name,
            drs.is_local,
            drs.is_primary_replica,
            drs.synchronization_state_desc,
            drs.synchronization_health_desc AS db_sync_health_desc,
            ISNULL(drs.log_send_queue_size,0) AS log_send_queue_size,
            ISNULL(drs.redo_queue_size,0) AS redo_queue_size
        FROM sys.availability_groups ag
        JOIN sys.availability_replicas ar
          ON ag.group_id = ar.group_id
        JOIN sys.dm_hadr_availability_replica_states ars
          ON ar.replica_id = ars.replica_id
        LEFT JOIN sys.dm_hadr_database_replica_states drs
          ON ars.replica_id = drs.replica_id
    )
    SELECT *
    FROM core
    ORDER BY ag_name, database_name, replica_server_name;
END
"@
    $rows = @(Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q)

    if (-not $rows) {
        return New-StsFinding -RunId $Context.RunId -Collector 'AgIntelligence' -Category 'AG' -CheckId 'AG-DB-SYNC' -CheckName 'AG database sync detail' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Info' -Severity 'Info' -Weight 2 `
            -Message 'No AG data returned. HADR may be disabled or no AGs exist on this instance.' -Evidence @{} -Recommendation 'None.' -Source 'tsql'
    }

    foreach ($r in $rows) {
        if (-not $r.database_name) { continue }

        $state = 'Healthy'
        if ($r.connected_state_desc -ne 'CONNECTED' -or $r.synchronization_health_desc -ne 'HEALTHY' -or $r.db_sync_health_desc -ne 'HEALTHY') {
            $state = 'Critical'
        } elseif ([int]$r.log_send_queue_size -gt $sendWarn -or [int]$r.redo_queue_size -gt $redoWarn -or $r.synchronization_state_desc -notin @('SYNCHRONIZED','SYNCHRONIZING')) {
            $state = 'Warning'
        }

        $out.Add(
            (New-StsFinding -RunId $Context.RunId -Collector 'AgIntelligence' -Category 'AGDatabase' -CheckId 'AG-DB-SYNC' -CheckName 'AG database sync detail' `
                -TargetType 'DatabaseReplica' -TargetName ("{0}|{1}|{2}" -f $r.ag_name, $r.database_name, $r.replica_server_name) -InstanceName $Context.InstanceName -State $state -Severity 'High' -Weight 10 `
                -Message ("AG database {0} on replica {1} is {2} / {3}." -f $r.database_name, $r.replica_server_name, $r.synchronization_state_desc, $r.db_sync_health_desc) `
                -Evidence @{ AG = $r.ag_name; Database = $r.database_name; Replica = $r.replica_server_name; Role = $r.role_desc; IsLocal = $r.is_local; IsPrimaryReplica = $r.is_primary_replica; ReplicaSyncHealth = $r.synchronization_health_desc; DbSyncHealth = $r.db_sync_health_desc; SyncState = $r.synchronization_state_desc; LogSendQueueKB = $r.log_send_queue_size; RedoQueueKB = $r.redo_queue_size; SendWarnKB = $sendWarn; RedoWarnKB = $redoWarn } `
                -Recommendation 'Investigate disconnected, unhealthy, or backlogged AG database replicas.' -Source 'tsql')
        )
    }

    $primaryRows = @($rows | Where-Object { $_.is_primary_replica -eq 1 -and $_.database_name })
    if ($primaryRows) {
        $primaryCounts = $primaryRows | Group-Object replica_server_name | ForEach-Object {
            [pscustomobject]@{ Replica = $_.Name; Count = $_.Count }
        }

        $maxPrimary = ($primaryCounts | Measure-Object Count -Maximum).Maximum
        $minPrimary = ($primaryCounts | Measure-Object Count -Minimum).Minimum
        if ($null -eq $minPrimary) { $minPrimary = 0 }
        $primarySkew = [int]$maxPrimary - [int]$minPrimary
        $primaryState = if ($primarySkew -gt $primarySkewWarn) { 'Warning' } else { 'Healthy' }
        $primarySummary = ($primaryCounts | Sort-Object Replica | ForEach-Object { "{0}:{1}" -f $_.Replica, $_.Count }) -join '; '

        $out.Add(
            (New-StsFinding -RunId $Context.RunId -Collector 'AgIntelligence' -Category 'AGPrimaryDistribution' -CheckId 'AG-PRIMARY-DISTRIBUTION' -CheckName 'AG primary distribution' `
                -TargetType 'AG' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State $primaryState -Severity 'Medium' -Weight 6 `
                -Message ("AG primary distribution skew is {0}." -f $primarySkew) `
                -Evidence @{ PrimaryCounts = $primarySummary; PrimarySkew = $primarySkew; WarnSkew = $primarySkewWarn } `
                -Recommendation 'Spread AG primaries more evenly if concentrated placement is not intentional.' -Source 'tsql')
        )
    }

    $out
}
