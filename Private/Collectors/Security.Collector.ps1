
function Invoke-StsCollectorSecurity {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $warnDays = [int]$Context.Settings.CertWarnDays
    $critDays = [int]$Context.Settings.CertCritDays
    $q = @"
SELECT name, subject, expiry_date
FROM master.sys.certificates
WHERE name NOT LIKE '##MS_%'
ORDER BY expiry_date;
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q

    if (-not $rows) {
        New-StsFinding -RunId $Context.RunId -Collector 'Security' -Category 'Certificates' -CheckId 'CERT-EXPIRY' -CheckName 'Certificate expiry' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Info' -Severity 'Info' -Weight 2 `
            -Message 'No user certificates found in master.' -Evidence @{} -Recommendation 'None.' -Source 'tsql'
        return
    }

    foreach ($cert in $rows) {
        $days = [math]::Floor(([datetime]$cert.expiry_date - (Get-Date)).TotalDays)
        $state = if ($days -le $critDays) { 'Critical' } elseif ($days -le $warnDays) { 'Warning' } else { 'Healthy' }

        New-StsFinding -RunId $Context.RunId -Collector 'Security' -Category 'Certificates' -CheckId 'CERT-EXPIRY' -CheckName 'Certificate expiry' `
            -TargetType 'Certificate' -TargetName $cert.name -InstanceName $Context.InstanceName -State $state -Severity 'High' -Weight 6 `
            -Message ("Certificate '{0}' expires in {1} day(s)." -f $cert.name, $days) `
            -Evidence @{ Subject = $cert.subject; ExpiryDate = $cert.expiry_date; DaysRemaining = $days } `
            -Recommendation 'Renew before expiry impacts endpoints, backup encryption, or related features.' -Source 'tsql'
    }
}
