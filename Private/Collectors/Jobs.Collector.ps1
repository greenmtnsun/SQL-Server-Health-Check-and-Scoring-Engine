# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Invoke-StsCollectorJobs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Check
    )

    $instanceName = [string]$Context.InstanceName
    $settings = $Context.Settings
    $lookbackHours = if ($settings.ContainsKey('JobFailureLookbackHrs')) { [int]$settings.JobFailureLookbackHrs } else { 72 }
    $started = Get-Date

    $query = @"
SET NOCOUNT ON;

WITH job_last_run AS
(
    SELECT
        j.job_id,
        j.name AS JobName,
        SUSER_SNAME(j.owner_sid) AS OwnerName,
        j.enabled AS IsEnabled,
        h.run_status,
        h.run_date,
        h.run_time,
        h.message,
        ROW_NUMBER() OVER
        (
            PARTITION BY j.job_id
            ORDER BY h.instance_id DESC
        ) AS rn
    FROM msdb.dbo.sysjobs j
    LEFT JOIN msdb.dbo.sysjobhistory h
        ON j.job_id = h.job_id
       AND h.step_id = 0
)
SELECT
    JobName,
    OwnerName,
    IsEnabled,
    run_status AS RunStatus,
    run_date AS RunDate,
    run_time AS RunTime,
    message AS JobMessage
FROM job_last_run
WHERE rn = 1
ORDER BY JobName;
"@

    try {
        $rows = Invoke-StsQuery -Context $Context -Query $query
    }
    catch {
        $evidence = @{
            InstanceName   = $Context.InstanceName
            LookbackHours  = $lookbackHours
            Error          = $_.Exception.Message
        }

        return New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'Jobs' `
            -Category 'Jobs' `
            -CheckId 'JOB-FAILURES' `
            -CheckName 'SQL Agent job health' `
            -TargetType 'Instance' `
            -TargetName $instanceName `
            -InstanceName $instanceName `
            -State 'Unknown' `
            -Severity 'High' `
            -Weight 8 `
            -Message 'Job inventory query failed.' `
            -Evidence $evidence `
            -Recommendation 'Validate msdb access and job history visibility.' `
            -Source 'tsql' `
            -DurationMs ([int]((Get-Date) - $started).TotalMilliseconds) `
            -ErrorId 'JOBS-QUERY-FAILED' `
            -ErrorMessage $_.Exception.Message
    }

    $findings = New-Object System.Collections.Generic.List[object]

    foreach ($row in @($rows)) {
        $jobName   = [string]$row.JobName
        $ownerName = [string]$row.OwnerName
        $isEnabled = if ($null -ne $row.IsEnabled) { ([int]$row.IsEnabled -eq 1) } else { $null }
        $runStatus = if ($null -ne $row.RunStatus) { [int]$row.RunStatus } else { $null }
        $jobMessage = [string]$row.JobMessage

        $lastRunDateTime = $null
        if ($row.RunDate -and $row.RunTime -and [string]$row.RunDate -ne '0') {
            try {
                $dateText = [string]$row.RunDate
                $timeText = ([string]$row.RunTime).PadLeft(6, '0')
                $lastRunDateTime = [datetime]::ParseExact("$dateText$timeText",'yyyyMMddHHmmss',$null)
            } catch {
                $lastRunDateTime = $null
            }
        }

        $lastRunAgeHours = if ($lastRunDateTime) {
            [math]::Round((New-TimeSpan -Start $lastRunDateTime -End (Get-Date)).TotalHours, 1)
        } else { $null }

        $evidence = @{
            InstanceName    = $Context.InstanceName
            JobName         = $jobName
            OwnerName       = $ownerName
            IsEnabled       = $isEnabled
            RunStatus       = $runStatus
            LastRunDateTime = $lastRunDateTime
            LastRunAgeHours = $lastRunAgeHours
            LookbackHours   = $lookbackHours
            JobMessage      = $jobMessage
        }

        $durationMs = [int]((Get-Date) - $started).TotalMilliseconds
        $jobState = 'Healthy'
        $jobSeverity = 'Info'
        $jobWeight = 8
        $jobText = "Last status for job '$jobName' is success."

        if ($isEnabled -eq $false) {
            $jobState = 'Info'
            $jobSeverity = 'Medium'
            $jobText = "Job '$jobName' is disabled."
        }
        elseif ($null -eq $runStatus) {
            $jobState = 'Info'
            $jobSeverity = 'Medium'
            $jobText = "No last-run status found for job '$jobName'."
        }
        elseif ($runStatus -ne 1) {
            $jobState = 'Warning'
            $jobSeverity = 'High'
            $jobText = "Last status for job '$jobName' is not success."
        }

        $findings.Add(
            (New-StsFinding `
                -RunId $Context.RunId `
                -Collector 'Jobs' `
                -Category 'Jobs' `
                -CheckId 'JOB-FAILURES' `
                -CheckName 'SQL Agent job health' `
                -TargetType 'Job' `
                -TargetName $jobName `
                -InstanceName $instanceName `
                -State $jobState `
                -Severity $jobSeverity `
                -Weight $jobWeight `
                -Message $jobText `
                -Evidence $evidence `
                -Recommendation 'Review failed or disabled jobs, especially backup and HA jobs.' `
                -Source 'tsql' `
                -DurationMs $durationMs)
        )

        $ownerState = 'Info'
        $ownerSeverity = 'Medium'
        $ownerWeight = 3
        $ownerMessage = "Job owner is '$ownerName'."

        if ([string]::IsNullOrWhiteSpace($ownerName)) {
            $ownerState = 'Warning'
            $ownerSeverity = 'High'
            $ownerMessage = "Job '$jobName' has no resolved owner."
        }

        $findings.Add(
            (New-StsFinding `
                -RunId $Context.RunId `
                -Collector 'Jobs' `
                -Category 'Ownership' `
                -CheckId 'JOB-OWNER' `
                -CheckName 'Job ownership sanity' `
                -TargetType 'Job' `
                -TargetName $jobName `
                -InstanceName $instanceName `
                -State $ownerState `
                -Severity $ownerSeverity `
                -Weight $ownerWeight `
                -Message $ownerMessage `
                -Evidence $evidence `
                -Recommendation 'Use a deliberate service/login owner model. Avoid ambiguous or missing ownership.' `
                -Source 'tsql' `
                -DurationMs $durationMs)
        )
    }

    return @($findings)
}
