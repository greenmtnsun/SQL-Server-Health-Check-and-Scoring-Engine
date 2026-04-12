
function Invoke-StsCollectorPerformance {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $cpuWarn = [int]$Context.Settings.CpuRunnableWarn
    $pleWarn = [int]$Context.Settings.PLEWarn
    $waitWarn = [int]$Context.Settings.WaitPctWarn
    $out = New-Object System.Collections.Generic.List[object]

    $qBlock = @"
SELECT er.session_id, er.blocking_session_id, er.wait_type, er.wait_time, DB_NAME(er.database_id) AS database_name
FROM sys.dm_exec_requests er
WHERE er.blocking_session_id <> 0;
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $qBlock

    if (-not $rows) {
        $out.Add(
            (New-StsFinding -RunId $Context.RunId -Collector 'Performance' -Category 'Blocking' -CheckId 'PERF-BLOCKING' -CheckName 'Blocking snapshot' `
                -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Healthy' -Severity 'Info' -Weight 7 `
                -Message 'No active blocked requests detected.' -Evidence @{} -Recommendation 'None.' -Source 'tsql')
        )
    } else {
        foreach ($r in $rows) {
            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'Performance' -Category 'Blocking' -CheckId 'PERF-BLOCKING' -CheckName 'Blocking snapshot' `
                    -TargetType 'Session' -TargetName ("SPID {0}" -f $r.session_id) -InstanceName $Context.InstanceName -State 'Warning' -Severity 'Medium' -Weight 7 `
                    -Message ("Session {0} is blocked by {1}." -f $r.session_id, $r.blocking_session_id) `
                    -Evidence @{ WaitType = $r.wait_type; WaitMs = $r.wait_time; Database = $r.database_name } `
                    -Recommendation 'Find the head blocker and review transaction scope, indexing, and query patterns.' -Source 'tsql')
            )
        }
    }

    try {
        $sched = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query @"
SELECT MAX(runnable_tasks_count) AS max_runnable_tasks
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE';
"@ | Select-Object -First 1
        $schedState = if ($sched -and [int]$sched.max_runnable_tasks -gt $cpuWarn) { 'Warning' } else { 'Healthy' }
        $out.Add(
            (New-StsFinding -RunId $Context.RunId -Collector 'Performance' -Category 'CPU' -CheckId 'PERF-RUNNABLE' -CheckName 'Runnable task pressure' `
                -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State $schedState -Severity 'Medium' -Weight 5 `
                -Message ("Max runnable tasks observed is {0}." -f $sched.max_runnable_tasks) `
                -Evidence @{ MaxRunnableTasks = $sched.max_runnable_tasks; WarnThreshold = $cpuWarn } `
                -Recommendation 'Sustained high runnable task counts can indicate CPU pressure.' -Source 'tsql')
        )
    } catch { }

    try {
        $ple = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query @"
SELECT TOP (1) cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy';
"@ | Select-Object -First 1
        $pleState = if ($ple -and [int64]$ple.cntr_value -lt $pleWarn) { 'Warning' } else { 'Info' }
        $out.Add(
            (New-StsFinding -RunId $Context.RunId -Collector 'Performance' -Category 'Memory' -CheckId 'PERF-PLE' -CheckName 'Page life expectancy snapshot' `
                -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State $pleState -Severity 'Medium' -Weight 4 `
                -Message ("PLE snapshot is {0}." -f $ple.cntr_value) `
                -Evidence @{ PLE = $ple.cntr_value; WarnThreshold = $pleWarn } `
                -Recommendation 'Interpret PLE carefully with NUMA and workload context. Use as one signal, not a verdict.' -Source 'tsql')
        )
    } catch { }

    try {
        $waits = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query @"
;WITH waits AS (
    SELECT wait_type, wait_time_ms,
           SUM(wait_time_ms) OVER() AS total_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT LIKE 'SLEEP%'
      AND wait_type NOT IN ('BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR','BROKER_TASK_STOP','BROKER_TO_FLUSH','BROKER_TRANSMITTER','CHECKPOINT_QUEUE','CHKPT','CLR_AUTO_EVENT','CLR_MANUAL_EVENT','CLR_SEMAPHORE','DBMIRROR_DBM_EVENT','DBMIRROR_EVENTS_QUEUE','DBMIRROR_WORKER_QUEUE','DBMIRRORING_CMD','DIRTY_PAGE_POLL','DISPATCHER_QUEUE_SEMAPHORE','EXECSYNC','FSAGENT','FT_IFTS_SCHEDULER_IDLE_WAIT','FT_IFTSHC_MUTEX','HADR_CLUSAPI_CALL','HADR_FILESTREAM_IOMGR_IOCOMPLETION','HADR_LOGCAPTURE_WAIT','HADR_NOTIFICATION_DEQUEUE','HADR_TIMER_TASK','HADR_WORK_QUEUE','KSOURCE_WAKEUP','LAZYWRITER_SLEEP','LOGMGR_QUEUE','ONDEMAND_TASK_QUEUE','PWAIT_ALL_COMPONENTS_INITIALIZED','PWAIT_DIRECTLOGCONSUMER_GETNEXT','QDS_PERSIST_TASK_MAIN_LOOP_SLEEP','QDS_ASYNC_QUEUE','QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP','QDS_SHUTDOWN_QUEUE','REDO_THREAD_PENDING_WORK','REQUEST_FOR_DEADLOCK_SEARCH','RESOURCE_QUEUE','SERVER_IDLE_CHECK','SLEEP_BPOOL_FLUSH','SLEEP_DBSTARTUP','SLEEP_DCOMSTARTUP','SLEEP_MASTERDBREADY','SLEEP_MASTERMDREADY','SLEEP_MASTERUPGRADED','SLEEP_MSDBSTARTUP','SLEEP_SYSTEMTASK','SLEEP_TASK','SLEEP_TEMPDBSTARTUP','SNI_HTTP_ACCEPT','SP_SERVER_DIAGNOSTICS_SLEEP','SQLTRACE_BUFFER_FLUSH','SQLTRACE_INCREMENTAL_FLUSH_SLEEP','SQLTRACE_WAIT_ENTRIES','WAIT_FOR_RESULTS','WAITFOR','WAITFOR_TASKSHUTDOWN','WAIT_XTP_RECOVERY','WAIT_XTP_HOST_WAIT','WAIT_XTP_OFFLINE_CKPT_NEW_LOG','WAIT_XTP_CKPT_CLOSE','XE_DISPATCHER_JOIN','XE_DISPATCHER_WAIT','XE_TIMER_EVENT')
)
SELECT TOP (5)
    wait_type,
    wait_time_ms,
    CAST(CASE WHEN total_ms = 0 THEN 0 ELSE (wait_time_ms * 100.0 / total_ms) END AS decimal(10,2)) AS pct
FROM waits
ORDER BY wait_time_ms DESC;
"@
        foreach ($w in @($waits)) {
            $state = if ([decimal]$w.pct -ge $waitWarn) { 'Warning' } else { 'Info' }
            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'Performance' -Category 'Waits' -CheckId 'PERF-WAITS' -CheckName 'Top wait category' `
                    -TargetType 'WaitType' -TargetName $w.wait_type -InstanceName $Context.InstanceName -State $state -Severity 'Medium' -Weight 3 `
                    -Message ("Top wait {0} represents {1}% of sampled cumulative waits." -f $w.wait_type, $w.pct) `
                    -Evidence @{ WaitType = $w.wait_type; WaitMs = $w.wait_time_ms; Percent = $w.pct; WarnPct = $waitWarn } `
                    -Recommendation 'Use waits as directional evidence. Correlate with CPU, I/O, blocking, and workload timing.' -Source 'tsql')
            )
        }
    } catch { }

    $out
}
