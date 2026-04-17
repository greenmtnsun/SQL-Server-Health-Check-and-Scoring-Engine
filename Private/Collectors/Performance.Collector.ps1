# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Invoke-StsCollectorPerformance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Check
    )

    $instanceName = [string]$Context.InstanceName
    $settings = $Context.Settings
    $cpuRunnableWarn = if ($settings.ContainsKey('CpuRunnableWarn')) { [int]$settings.CpuRunnableWarn } else { 12 }
    $pleWarn = if ($settings.ContainsKey('PLEWarn')) { [int]$settings.PLEWarn } else { 300 }
    $waitPctWarn = if ($settings.ContainsKey('WaitPctWarn')) { [double]$settings.WaitPctWarn } else { 40 }
    $started = Get-Date
    $findings = New-Object System.Collections.Generic.List[object]

    $snapshotQuery = @"
SET NOCOUNT ON;

SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0) AS BlockingCount,
    (SELECT ISNULL(MAX(runnable_tasks_count),0) FROM sys.dm_os_schedulers WHERE status = 'VISIBLE ONLINE') AS MaxRunnableTasks,
    (
        SELECT ISNULL(MIN(cntr_value),0)
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'Page life expectancy'
    ) AS PLE;
"@

    try {
        $snapshot = Invoke-StsQuery -Context $Context -Query $snapshotQuery | Select-Object -First 1
    }
    catch {
        $evidence = @{
            InstanceName    = $Context.InstanceName
            Error           = $_.Exception.Message
            CpuRunnableWarn = $cpuRunnableWarn
            PLEWarn         = $pleWarn
            WaitPctWarn     = $waitPctWarn
        }

        return New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'Performance' `
            -Category 'Performance' `
            -CheckId 'PERF-BLOCKING' `
            -CheckName 'Performance snapshot' `
            -TargetType 'Instance' `
            -TargetName $instanceName `
            -InstanceName $instanceName `
            -State 'Unknown' `
            -Severity 'High' `
            -Weight 8 `
            -Message 'Performance snapshot query failed.' `
            -Evidence $evidence `
            -Recommendation 'Validate DMV access and permissions.' `
            -Source 'tsql' `
            -DurationMs ([int]((Get-Date) - $started).TotalMilliseconds) `
            -ErrorId 'PERF-SNAPSHOT-FAILED' `
            -ErrorMessage $_.Exception.Message
    }

    $blockingCount = if ($null -ne $snapshot.BlockingCount) { [int]$snapshot.BlockingCount } else { 0 }
    $maxRunnableTasks = if ($null -ne $snapshot.MaxRunnableTasks) { [int]$snapshot.MaxRunnableTasks } else { 0 }
    $ple = if ($null -ne $snapshot.PLE) { [int]$snapshot.PLE } else { 0 }

    $commonEvidence = @{
        InstanceName     = $Context.InstanceName
        BlockingCount    = $blockingCount
        MaxRunnableTasks = $maxRunnableTasks
        PLE              = $ple
        CpuRunnableWarn  = $cpuRunnableWarn
        PLEWarn          = $pleWarn
        WaitPctWarn      = $waitPctWarn
    }

    $durationMs = [int]((Get-Date) - $started).TotalMilliseconds

    $blockingState = if ($blockingCount -gt 0) { 'Warning' } else { 'Healthy' }
    $blockingMessage = if ($blockingCount -gt 0) { "$blockingCount active blocked request(s) detected." } else { 'No active blocked requests detected.' }

    $findings.Add(
        (New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'Performance' `
            -Category 'Blocking' `
            -CheckId 'PERF-BLOCKING' `
            -CheckName 'Blocking snapshot' `
            -TargetType 'Instance' `
            -TargetName $instanceName `
            -InstanceName $instanceName `
            -State $blockingState `
            -Severity 'Info' `
            -Weight 7 `
            -Message $blockingMessage `
            -Evidence $commonEvidence `
            -Recommendation 'Investigate blocking chains if this condition persists.' `
            -Source 'tsql' `
            -DurationMs $durationMs)
    )

    $runnableState = if ($maxRunnableTasks -gt $cpuRunnableWarn) { 'Warning' } else { 'Healthy' }
    $runnableMessage = "Max runnable tasks observed is $maxRunnableTasks."

    $findings.Add(
        (New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'Performance' `
            -Category 'CPU' `
            -CheckId 'PERF-RUNNABLE' `
            -CheckName 'Runnable task pressure' `
            -TargetType 'Instance' `
            -TargetName $instanceName `
            -InstanceName $instanceName `
            -State $runnableState `
            -Severity 'Medium' `
            -Weight 5 `
            -Message $runnableMessage `
            -Evidence $commonEvidence `
            -Recommendation 'Sustained high runnable task counts can indicate CPU pressure.' `
            -Source 'tsql' `
            -DurationMs $durationMs)
    )

    $pleState = if ($ple -gt 0 -and $ple -lt $pleWarn) { 'Warning' } else { 'Info' }
    $pleMessage = "PLE snapshot is $ple."

    $findings.Add(
        (New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'Performance' `
            -Category 'Memory' `
            -CheckId 'PERF-PLE' `
            -CheckName 'Page life expectancy snapshot' `
            -TargetType 'Instance' `
            -TargetName $instanceName `
            -InstanceName $instanceName `
            -State $pleState `
            -Severity 'Medium' `
            -Weight 4 `
            -Message $pleMessage `
            -Evidence $commonEvidence `
            -Recommendation 'Interpret PLE carefully with NUMA and workload context. Use as one signal, not a verdict.' `
            -Source 'tsql' `
            -DurationMs $durationMs)
    )

    $waitQuery = @"
SET NOCOUNT ON;

WITH waits AS
(
    SELECT
        wait_type,
        wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN
    (
        'SLEEP_TASK',
        'BROKER_TASK_STOP',
        'BROKER_TO_FLUSH',
        'SQLTRACE_BUFFER_FLUSH',
        'CLR_AUTO_EVENT',
        'CLR_MANUAL_EVENT',
        'LAZYWRITER_SLEEP',
        'SLEEP_SYSTEMTASK',
        'XE_TIMER_EVENT',
        'XE_DISPATCHER_WAIT',
        'FT_IFTS_SCHEDULER_IDLE_WAIT',
        'LOGMGR_QUEUE',
        'REQUEST_FOR_DEADLOCK_SEARCH',
        'CHECKPOINT_QUEUE',
        'BROKER_EVENTHANDLER',
        'TRACEWRITE',
        'WAITFOR',
        'DBMIRROR_DBM_EVENT',
        'DBMIRROR_EVENTS_QUEUE',
        'BROKER_RECEIVE_WAITFOR',
        'ONDEMAND_TASK_QUEUE',
        'DIRTY_PAGE_POLL',
        'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        'SP_SERVER_DIAGNOSTICS_SLEEP'
    )
      AND wait_time_ms > 0
)
SELECT TOP (5)
    wait_type AS WaitType,
    wait_time_ms AS WaitMs,
    CAST(wait_time_ms * 100.0 / NULLIF(SUM(wait_time_ms) OVER (),0) AS decimal(10,2)) AS WaitPct
FROM waits
ORDER BY wait_time_ms DESC;
"@

    try { $waitRows = @(Invoke-StsQuery -Context $Context -Query $waitQuery) }
    catch { $waitRows = @() }

    foreach ($row in $waitRows) {
        $waitType = [string]$row.WaitType
        $waitMs = if ($null -ne $row.WaitMs) { [int64]$row.WaitMs } else { 0 }
        $waitPct = if ($null -ne $row.WaitPct) { [double]$row.WaitPct } else { 0 }

        $waitEvidence = @{
            InstanceName = $Context.InstanceName
            WaitType     = $waitType
            WaitMs       = $waitMs
            Percent      = $waitPct
            WarnPct      = $waitPctWarn
        }

        $waitState = if ($waitPct -gt $waitPctWarn) { 'Warning' } else { 'Info' }
        $waitMessage = "Top wait $waitType represents $waitPct% of sampled cumulative waits."

        $findings.Add(
            (New-StsFinding `
                -RunId $Context.RunId `
                -Collector 'Performance' `
                -Category 'Waits' `
                -CheckId 'PERF-WAITS' `
                -CheckName 'Top wait category' `
                -TargetType 'WaitType' `
                -TargetName $waitType `
                -InstanceName $instanceName `
                -State $waitState `
                -Severity 'Medium' `
                -Weight 3 `
                -Message $waitMessage `
                -Evidence $waitEvidence `
                -Recommendation 'Use waits as directional evidence. Correlate with CPU, I/O, blocking, and workload timing.' `
                -Source 'tsql' `
                -DurationMs $durationMs)
        )
    }

    return @($findings)
}
