
function Invoke-StsCollectorDatabases {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $q = @"
SELECT
    name, state_desc, recovery_model_desc, is_read_only, is_auto_close_on, is_auto_shrink_on,
    page_verify_option_desc, log_reuse_wait_desc
FROM sys.databases
ORDER BY name;
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q

    foreach ($db in $rows) {
        $state = if ($db.state_desc -eq 'ONLINE') { 'Healthy' } elseif ($db.state_desc -eq 'OFFLINE') { 'Info' } else { 'Critical' }
        $recommendation = if ($state -eq 'Critical') { 'Investigate databases not ONLINE or stuck in recovery-related states.' } else { 'None.' }

        New-StsFinding -RunId $Context.RunId -Collector 'Databases' -Category 'Databases' -CheckId 'DB-STATE' -CheckName 'Database state' `
            -TargetType 'Database' -TargetName $db.name -InstanceName $Context.InstanceName -State $state -Severity 'High' -Weight 10 `
            -Message ("Database state is {0}." -f $db.state_desc) `
            -Evidence @{ RecoveryModel = $db.recovery_model_desc; ReadOnly = [bool]$db.is_read_only; AutoClose = [bool]$db.is_auto_close_on; AutoShrink = [bool]$db.is_auto_shrink_on; PageVerify = $db.page_verify_option_desc; LogReuseWait = $db.log_reuse_wait_desc } `
            -Recommendation $recommendation -Source 'tsql'
    }
}
