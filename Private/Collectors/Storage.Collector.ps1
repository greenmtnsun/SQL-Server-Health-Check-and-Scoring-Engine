
function Invoke-StsCollectorStorage {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $warnPct = [int]$Context.Settings.DiskFreeWarnPct
    $critPct = [int]$Context.Settings.DiskFreeCritPct

    if (-not (Get-Command Get-DbaDiskSpace -ErrorAction SilentlyContinue)) {
        throw "Get-DbaDiskSpace not available."
    }

    $computerName = ($Context.InstanceName -split '\\')[0]
    $rows = Get-DbaDiskSpace -ComputerName $computerName -EnableException

    foreach ($disk in $rows) {
        $freePct = [double]$disk.PercentFree
        $state = if ($freePct -le $critPct) { 'Critical' } elseif ($freePct -le $warnPct) { 'Warning' } else { 'Healthy' }

        New-StsFinding -RunId $Context.RunId -Collector 'Storage' -Category 'Disk' -CheckId 'DISK-FREE' -CheckName 'Disk free space' `
            -TargetType 'Disk' -TargetName $disk.Name -InstanceName $Context.InstanceName -State $state -Severity 'High' -Weight 9 `
            -Message ("Disk {0} has {1}% free." -f $disk.Name, [math]::Round($freePct,1)) `
            -Evidence @{ PercentFree = $freePct; FreeGB = $disk.Free; WarnPct = $warnPct; CritPct = $critPct } `
            -Recommendation 'Expand space or reduce growth pressure before the volume fills.' -Source 'dbatools'
    }
}
