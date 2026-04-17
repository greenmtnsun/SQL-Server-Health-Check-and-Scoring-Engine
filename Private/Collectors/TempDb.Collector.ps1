# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Invoke-StsCollectorTempDb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Check
    )

    $instanceName = [string]$Context.InstanceName
    $settings = $Context.Settings
    $warnDataFileCount = if ($settings.ContainsKey('TempDbFileCountWarn')) { [int]$settings.TempDbFileCountWarn } else { 4 }
    $started = Get-Date
    $findings = New-Object System.Collections.Generic.List[object]

    $query = @"
SET NOCOUNT ON;

SELECT
    COUNT(*) AS FileCount,
    SUM(CAST(size AS bigint)) * 8 / 1024 AS TotalSizeMB,
    SUM(CASE WHEN type_desc = 'ROWS' THEN 1 ELSE 0 END) AS DataFileCount,
    SUM(CASE WHEN type_desc = 'LOG'  THEN 1 ELSE 0 END) AS LogFileCount
FROM tempdb.sys.database_files;
"@

    try {
        $row = Invoke-StsQuery -Context $Context -Query $query | Select-Object -First 1
    }
    catch {
        $evidence = @{
            InstanceName      = $Context.InstanceName
            DatabaseName      = 'tempdb'
            WarnDataFileCount = $warnDataFileCount
            Error             = $_.Exception.Message
        }

        return New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'TempDb' `
            -Category 'TempDb' `
            -CheckId 'TEMPDB-FILES' `
            -CheckName 'TempDB layout' `
            -TargetType 'Database' `
            -TargetName 'tempdb' `
            -InstanceName $instanceName `
            -State 'Unknown' `
            -Severity 'High' `
            -Weight 7 `
            -Message 'TempDB layout query failed.' `
            -Evidence $evidence `
            -Recommendation 'Validate tempdb metadata access and query execution path.' `
            -Source 'tsql' `
            -DurationMs ([int]((Get-Date) - $started).TotalMilliseconds) `
            -ErrorId 'TEMPDB-QUERY-FAILED' `
            -ErrorMessage $_.Exception.Message
    }

    $fileCount = if ($null -ne $row.FileCount) { [int]$row.FileCount } else { $null }
    $dataFileCount = if ($null -ne $row.DataFileCount) { [int]$row.DataFileCount } else { $null }
    $logFileCount = if ($null -ne $row.LogFileCount) { [int]$row.LogFileCount } else { $null }
    $totalSizeMB = if ($null -ne $row.TotalSizeMB) { [int64]$row.TotalSizeMB } else { $null }

    $state = 'Info'
    $severity = 'Medium'
    $message = 'TempDB layout inventoried.'
    $weight = 7

    if ($null -eq $dataFileCount) {
        $state = 'Unknown'
        $severity = 'High'
        $message = 'TempDB data file count could not be determined.'
    }
    elseif ($dataFileCount -lt $warnDataFileCount) {
        $state = 'Info'
        $severity = 'Medium'
        $message = "TempDB has $dataFileCount data file(s), below the review threshold of $warnDataFileCount."
    }

    $evidence = @{
        InstanceName      = $Context.InstanceName
        DatabaseName      = 'tempdb'
        FileCount         = $fileCount
        DataFileCount     = $dataFileCount
        LogFileCount      = $logFileCount
        TotalSizeMB       = $totalSizeMB
        WarnDataFileCount = $warnDataFileCount
    }

    $findings.Add(
        (New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'TempDb' `
            -Category 'TempDb' `
            -CheckId 'TEMPDB-FILES' `
            -CheckName 'TempDB layout' `
            -TargetType 'Database' `
            -TargetName 'tempdb' `
            -InstanceName $instanceName `
            -State $state `
            -Severity $severity `
            -Weight $weight `
            -Message $message `
            -Evidence $evidence `
            -Recommendation 'Tune tempdb data file count, size, and growth settings to match workload and contention profile.' `
            -Source 'tsql' `
            -DurationMs ([int]((Get-Date) - $started).TotalMilliseconds))
    )

    return @($findings)
}
