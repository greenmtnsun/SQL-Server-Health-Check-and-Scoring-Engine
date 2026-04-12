
function Invoke-StsCollectorShares {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $q = @"
SELECT DISTINCT physical_name
FROM sys.master_files
WHERE physical_name LIKE '\\\\%'
ORDER BY physical_name;
"@
    $rows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $q
    $paths = @($rows | Select-Object -ExpandProperty physical_name)

    if (-not $paths) {
        New-StsFinding -RunId $Context.RunId -Collector 'Shares' -Category 'Paths' -CheckId 'SHARE-PATHS' -CheckName 'UNC path validation' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Healthy' -Severity 'Info' -Weight 7 `
            -Message 'No UNC-backed SQL file paths detected in sys.master_files.' -Evidence @{} -Recommendation 'None.' -Source 'tsql'
        return
    }

    foreach ($p in $paths) {
        try {
            $escaped = $p.Replace("'", "''")
            $probe = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query @"
DECLARE @r TABLE(FileExists int, FileIsDirectory int, ParentDirExists int);
INSERT @r EXEC master.dbo.xp_fileexist N'$escaped';
SELECT TOP (1) FileExists, FileIsDirectory, ParentDirExists FROM @r;
"@
            $first = $probe | Select-Object -First 1
            $state = 'Info'
            $msg = 'UNC-backed SQL path detected.'
            if ($first -and [int]$first.ParentDirExists -eq 0 -and [int]$first.FileExists -eq 0 -and [int]$first.FileIsDirectory -eq 0) {
                $state = 'Warning'
                $msg = 'UNC-backed SQL path detected but xp_fileexist did not confirm reachability.'
            }

            New-StsFinding -RunId $Context.RunId -Collector 'Shares' -Category 'Paths' -CheckId 'SHARE-PATHS' -CheckName 'UNC path reachability probe' `
                -TargetType 'Path' -TargetName $p -InstanceName $Context.InstanceName -State $state -Severity 'Medium' -Weight 7 `
                -Message $msg -Evidence @{ Path = $p; FileExists = $first.FileExists; FileIsDirectory = $first.FileIsDirectory; ParentDirExists = $first.ParentDirExists } `
                -Recommendation 'Validate SQL Server service-account access to backup and data UNC targets.' -Source 'tsql'
        } catch {
            New-StsFinding -RunId $Context.RunId -Collector 'Shares' -Category 'Paths' -CheckId 'SHARE-PATHS' -CheckName 'UNC path reachability probe' `
                -TargetType 'Path' -TargetName $p -InstanceName $Context.InstanceName -State 'Unknown' -Severity 'Medium' -Weight 7 `
                -Message 'Could not run UNC reachability probe.' -Evidence @{ Path = $p } `
                -Recommendation 'xp_fileexist may be blocked or rights may be insufficient. Validate manually.' -Source 'tsql'
        }
    }
}
