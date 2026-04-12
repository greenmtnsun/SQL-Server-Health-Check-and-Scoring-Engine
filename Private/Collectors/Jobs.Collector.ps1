
function Invoke-StsCollectorJobs {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $lookback = [int]$Context.Settings.JobFailureLookbackHrs
    $q = @"
WITH jh AS (
    SELECT
        j.name,
        j.enabled,
        SUSER_SNAME(j.owner_sid) AS owner_name,
        h.run_status,
        h.message,
        msdb.dbo.agent_datetime(h.run_date, h.run_time) AS run_datetime,
        ROW_NUMBER() OVER(PARTITION BY j.job_id ORDER BY h.instance_id DESC) rn
    FROM msdb.dbo.sysjobs j
    LEFT JOIN msdb.dbo.sysjobhistory h
      ON j.job_id = h.job_id
     AND h.step_id = 0
)
SELECT * FROM jh WHERE rn = 1 ORDER BY name;
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q -Database msdb

    foreach ($job in $rows) {
        if ($null -eq $job.run_status) {
            $state = if ([bool]$job.enabled) { 'Info' } else { 'Warning' }
            $message = "Job has no recorded run history yet."
            $severity = 'Medium'
        } elseif (-not [bool]$job.enabled) {
            $state = 'Warning'
            $message = ("Job '{0}' is disabled." -f $job.name)
            $severity = 'High'
        } elseif ([int]$job.run_status -eq 0) {
            $state = 'Critical'
            $message = ("Last status for job '{0}' is failure." -f $job.name)
            $severity = 'High'
        } elseif ([int]$job.run_status -eq 1) {
            $state = 'Healthy'
            $message = ("Last status for job '{0}' is success." -f $job.name)
            $severity = 'Info'
        } else {
            $state = 'Warning'
            $message = ("Last status for job '{0}' is {1}." -f $job.name, $job.run_status)
            $severity = 'Medium'
        }

        New-StsFinding -RunId $Context.RunId -Collector 'Jobs' -Category 'Jobs' -CheckId 'JOB-FAILURES' -CheckName 'SQL Agent job health' `
            -TargetType 'Job' -TargetName $job.name -InstanceName $Context.InstanceName -State $state -Severity $severity -Weight 8 `
            -Message $message `
            -Evidence @{ Enabled = [bool]$job.enabled; Owner = $job.owner_name; LastRun = $job.run_datetime; Message = $job.message; LookbackHours = $lookback; RunStatus = $job.run_status } `
            -Recommendation 'Review failed or disabled jobs, especially backup and HA jobs.' -Source 'tsql'

        $ownerState = if ([string]::IsNullOrWhiteSpace([string]$job.owner_name) -or $job.owner_name -eq 'sa') { 'Warning' } else { 'Info' }
        New-StsFinding -RunId $Context.RunId -Collector 'Jobs' -Category 'Ownership' -CheckId 'JOB-OWNER' -CheckName 'Job ownership sanity' `
            -TargetType 'Job' -TargetName $job.name -InstanceName $Context.InstanceName -State $ownerState -Severity 'Medium' -Weight 3 `
            -Message ("Job owner is '{0}'." -f $job.owner_name) `
            -Evidence @{ Owner = $job.owner_name } `
            -Recommendation 'Use a deliberate service/login owner model. Avoid ambiguous or missing ownership.' -Source 'tsql'
    }
}
