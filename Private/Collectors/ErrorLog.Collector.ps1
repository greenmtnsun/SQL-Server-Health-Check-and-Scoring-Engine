# STS:
# FileVersion: 1.0.1
# RequiresModuleVersion: 6.9.0

function Invoke-StsCollectorErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Check
    )

    $instanceName = [string]$Context.InstanceName
    $settings = $Context.Settings

    $lookbackHours = if ($settings.ContainsKey('ErrorLogLookbackHours')) {
        [int]$settings.ErrorLogLookbackHours
    } else {
        72
    }

    $started = Get-Date
    $since = (Get-Date).AddHours(-1 * $lookbackHours)
    $findings = New-Object System.Collections.Generic.List[object]

    $patterns = @(
        @{ Name = 'stack dump'; Pattern = 'stack dump' },
        @{ Name = 'assert'; Pattern = '\bassert\b' },
        @{ Name = 'corruption'; Pattern = '\b(corrupt|corruption)\b' },
        @{ Name = 'i/o error'; Pattern = '\bi/o error\b' },
        @{ Name = 'severity 20+'; Pattern = '\bseverity[: ]+(2[0-5])\b' },
        @{ Name = 'deadlock'; Pattern = '\bdeadlock\b' }
    )

    try {
        if (-not $Context.HasDbatools) {
            throw "dbatools is required for the current ErrorLog collector implementation."
        }

        $elogParams = @{
            SqlInstance = $instanceName
            After       = $since
            ErrorAction = 'Stop'
        }

        if ($Context.PSObject.Properties['SqlCredential'] -and $null -ne $Context.SqlCredential) {
            $elogParams.SqlCredential = $Context.SqlCredential
        }

        $logRows = @(Get-DbaErrorLog @elogParams)
    }
    catch {
        $evidence = @{
            InstanceName  = $Context.InstanceName
            LookbackHours = $lookbackHours
            Since         = $since
            Error         = $_.Exception.Message
        }

        return New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'ErrorLog' `
            -Category 'ErrorLog' `
            -CheckId 'ERRORLOG-SCAN' `
            -CheckName 'Error log scan' `
            -TargetType 'Instance' `
            -TargetName $instanceName `
            -InstanceName $instanceName `
            -State 'Unknown' `
            -Severity 'High' `
            -Weight 6 `
            -Message 'Error log scan failed.' `
            -Evidence $evidence `
            -Recommendation 'Validate dbatools availability, connectivity, and permission to read SQL error logs.' `
            -Source 'dbatools' `
            -DurationMs ([int]((Get-Date) - $started).TotalMilliseconds) `
            -ErrorId 'ERRORLOG-SCAN-FAILED' `
            -ErrorMessage $_.Exception.Message
    }

    $matches = New-Object System.Collections.Generic.List[object]

    foreach ($row in @($logRows)) {
        $text = ''
        $logDate = $null
        $processInfo = $null

        if ($row.PSObject.Properties['Text']) {
            $text = [string]$row.Text
        }
        elseif ($row.PSObject.Properties['Message']) {
            $text = [string]$row.Message
        }

        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        if ($row.PSObject.Properties['LogDate']) {
            try { $logDate = [datetime]$row.LogDate } catch { $logDate = $null }
        }

        if ($row.PSObject.Properties['ProcessInfo']) {
            try { $processInfo = [string]$row.ProcessInfo } catch { $processInfo = $null }
        }

        foreach ($rule in $patterns) {
            try {
                if ($text -match $rule.Pattern) {
                    $matches.Add([pscustomobject]@{
                        Pattern     = [string]$rule.Name
                        LogDate     = $logDate
                        ProcessInfo = $processInfo
                        MessageText = $text
                    })
                    break
                }
            }
            catch {
                continue
            }
        }
    }

    $matchCount = @($matches).Count

    $topPatterns = @(
        $matches |
        Group-Object Pattern |
        Sort-Object Count -Descending |
        Select-Object -First 5 |
        ForEach-Object { "{0} ({1})" -f $_.Name, $_.Count }
    )

    $sampleMessages = @(
        $matches |
        Select-Object -First 3 |
        ForEach-Object {
            $msg = [string]$_.MessageText
            if ($msg.Length -gt 180) { $msg.Substring(0,180) + '...' } else { $msg }
        }
    )

    $state = 'Healthy'
    $severity = 'Info'
    $message = 'No curated high-signal error log patterns found in lookback window.'
    $recommendation = 'None.'

    if ($matchCount -gt 0) {
        $state = 'Warning'
        $severity = 'Medium'
        $message = "Found $matchCount curated high-signal error log match(es) in the last $lookbackHours hour(s)."
        $recommendation = 'Review the matched log entries and confirm whether they indicate active operational problems.'
    }

    $evidence = @{
        InstanceName   = $Context.InstanceName
        LookbackHours  = $lookbackHours
        Since          = $since
        MatchCount     = $matchCount
        TopPatterns    = ($topPatterns -join '; ')
        SampleMessages = ($sampleMessages -join ' | ')
    }

    $findings.Add(
        (New-StsFinding `
            -RunId $Context.RunId `
            -Collector 'ErrorLog' `
            -Category 'ErrorLog' `
            -CheckId 'ERRORLOG-SCAN' `
            -CheckName 'Error log scan' `
            -TargetType 'Instance' `
            -TargetName $instanceName `
            -InstanceName $instanceName `
            -State $state `
            -Severity $severity `
            -Weight 6 `
            -Message $message `
            -Evidence $evidence `
            -Recommendation $recommendation `
            -Source 'dbatools' `
            -DurationMs ([int]((Get-Date) - $started).TotalMilliseconds))
    )

    return @($findings)
}
