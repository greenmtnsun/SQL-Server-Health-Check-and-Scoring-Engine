function Invoke-StsCollectorInstance {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $versionQuery = @"
SELECT
    @@SERVERNAME AS ServerName,
    @@VERSION AS VersionString,
    CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) AS Edition,
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(256)) AS ProductVersion,
    CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(256)) AS ProductLevel,
    sqlserver_start_time AS StartTime
FROM sys.dm_os_sys_info;
"@
    $version = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $versionQuery | Select-Object -First 1

    $memQuery = @"
SELECT
    CAST(value_in_use AS bigint) AS value_in_use,
    name
FROM sys.configurations
WHERE name IN ('min server memory (MB)','max server memory (MB)')
ORDER BY name;
"@
    $memRows = @(Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $memQuery)
    $minMem = ($memRows | Where-Object name -eq 'min server memory (MB)' | Select-Object -ExpandProperty value_in_use -First 1)
    $maxMem = ($memRows | Where-Object name -eq 'max server memory (MB)' | Select-Object -ExpandProperty value_in_use -First 1)

    @(
        (New-StsFinding -RunId $Context.RunId -Collector 'Instance' -Category 'Instance' -CheckId 'INST-CONNECT' -CheckName 'Instance connectivity' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Healthy' -Severity 'Info' -Weight 10 `
            -Message ("Connected to {0}." -f $version.ServerName) `
            -Evidence @{ Edition = $version.Edition; ProductVersion = $version.ProductVersion; ProductLevel = $version.ProductLevel; StartTime = $version.StartTime; QueryPath = 'Invoke-StsQuery/TrustServerCertificate' } `
            -Recommendation 'None.' -Source 'tsql'),

        (New-StsFinding -RunId $Context.RunId -Collector 'Instance' -Category 'Configuration' -CheckId 'INST-MEMORY-CONFIG' -CheckName 'Memory configuration' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Info' -Severity 'Low' -Weight 4 `
            -Message 'Memory settings inventoried.' `
            -Evidence @{ MinServerMemoryMB = $minMem; MaxServerMemoryMB = $maxMem } `
            -Recommendation 'Validate max memory leaves headroom for the OS.' -Source 'tsql')
    )
}
