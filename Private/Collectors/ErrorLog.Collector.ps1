
function Invoke-StsCollectorErrorLog {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    if (-not (Get-Command Get-DbaErrorLog -ErrorAction SilentlyContinue)) {
        New-StsFinding -RunId $Context.RunId -Collector 'ErrorLog' -Category 'ErrorLog' -CheckId 'ERRORLOG-SCAN' -CheckName 'Error log scan' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Unknown' -Severity 'Medium' -Weight 6 `
            -Message 'Get-DbaErrorLog not available.' -Evidence @{} -Recommendation 'Install or import dbatools.' -Source 'engine'
        return
    }

    $since = (Get-Date).AddHours(-1 * [int]$Context.Settings.ErrorLogLookbackHours)
    $logs = Get-DbaErrorLog -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -After $since -EnableException |
        Where-Object { $_.Text -match 'error|severity|i/o|fail|corrupt|stack|assert|deadlock' }

    if (-not $logs) {
        New-StsFinding -RunId $Context.RunId -Collector 'ErrorLog' -Category 'ErrorLog' -CheckId 'ERRORLOG-SCAN' -CheckName 'Error log scan' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Healthy' -Severity 'Info' -Weight 6 `
            -Message 'No notable error log patterns found in lookback window.' -Evidence @{ LookbackHours = $Context.Settings.ErrorLogLookbackHours } `
            -Recommendation 'None.' -Source 'dbatools'
        return
    }

    $sample = ($logs | Select-Object -First 3 | ForEach-Object { $_.Text }) -join ' | '
    New-StsFinding -RunId $Context.RunId -Collector 'ErrorLog' -Category 'ErrorLog' -CheckId 'ERRORLOG-SCAN' -CheckName 'Error log scan' `
        -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Warning' -Severity 'Medium' -Weight 6 `
        -Message 'Potentially important patterns found in SQL error log.' -Evidence @{ LookbackHours = $Context.Settings.ErrorLogLookbackHours; Sample = $sample } `
        -Recommendation 'Review full error log output and correlate with jobs, storage, and HA findings.' -Source 'dbatools'
}
