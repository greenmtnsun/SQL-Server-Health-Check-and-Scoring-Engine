
function Invoke-StsCollectorReplication {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $out = New-Object System.Collections.Generic.List[object]

    $q = @"
SELECT
    SERVERPROPERTY('IsDistributor') AS is_distributor,
    SERVERPROPERTY('IsPublisher') AS is_publisher,
    SERVERPROPERTY('IsSubscriber') AS is_subscriber;
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q
    $row = $rows | Select-Object -First 1

    if (-not $row) {
        $out.Add(
            (New-StsFinding -RunId $Context.RunId -Collector 'Replication' -Category 'Replication' -CheckId 'REPL-SUMMARY' -CheckName 'Replication summary' `
                -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Unknown' -Severity 'Medium' -Weight 8 `
                -Message 'Unable to determine replication roles.' -Evidence @{} -Recommendation 'Verify permissions and metadata visibility.' -Source 'tsql')
        )
        return $out
    }

    $enabled = ([int]$row.is_distributor -eq 1) -or ([int]$row.is_publisher -eq 1) -or ([int]$row.is_subscriber -eq 1)
    $state = if ($enabled) { 'Info' } else { 'Healthy' }
    $msg = if ($enabled) { 'Replication roles detected on this instance.' } else { 'No replication roles detected on this instance.' }

    $out.Add(
        (New-StsFinding -RunId $Context.RunId -Collector 'Replication' -Category 'Replication' -CheckId 'REPL-SUMMARY' -CheckName 'Replication summary' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State $state -Severity 'Info' -Weight 8 `
            -Message $msg -Evidence @{ IsDistributor = $row.is_distributor; IsPublisher = $row.is_publisher; IsSubscriber = $row.is_subscriber } `
            -Recommendation 'If replication is in use, review agent health and latency findings.' -Source 'tsql')
    )

    if ($enabled) {
        try {
            $qAgent = @"
SELECT TOP (20)
    name,
    enabled,
    date_modified
FROM msdb.dbo.sysjobs
WHERE category_id IN (10,13,14,15,16,17)
ORDER BY name;
"@
            $agents = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $qAgent -Database msdb
            foreach ($a in @($agents)) {
                $agentState = if ([bool]$a.enabled) { 'Info' } else { 'Warning' }
                $out.Add(
                    (New-StsFinding -RunId $Context.RunId -Collector 'Replication' -Category 'Agents' -CheckId 'REPL-AGENT' -CheckName 'Replication agent job presence' `
                        -TargetType 'Job' -TargetName $a.name -InstanceName $Context.InstanceName -State $agentState -Severity 'Medium' -Weight 4 `
                        -Message ("Replication-related job '{0}' inventoried." -f $a.name) `
                        -Evidence @{ Enabled = [bool]$a.enabled; DateModified = $a.date_modified } `
                        -Recommendation 'Check job history and latency if replication is mission-critical.' -Source 'tsql')
                )
            }
        } catch { }
    }

    $out
}
