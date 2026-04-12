
function Invoke-StsCollectorFileLayout {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $vlfWarn = [int]$Context.Settings.VlfWarnCount
    $growthWarn = [int]$Context.Settings.FileGrowthPctWarn
    $out = New-Object System.Collections.Generic.List[object]

    $qGrowth = @"
SELECT DB_NAME(database_id) AS database_name, name, type_desc, growth, is_percent_growth
FROM sys.master_files
ORDER BY DB_NAME(database_id), name;
"@
    $growthRows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query $qGrowth

    foreach ($f in $growthRows) {
        if ([int]$f.is_percent_growth -eq 1 -and [int]$f.growth -ge $growthWarn) {
            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'FileLayout' -Category 'Growth' -CheckId 'FILE-GROWTH' -CheckName 'Risky percent growth setting' `
                    -TargetType 'File' -TargetName ("{0}|{1}" -f $f.database_name, $f.name) -InstanceName $Context.InstanceName -State 'Warning' -Severity 'Medium' -Weight 5 `
                    -Message ("File growth is set to {0}%." -f $f.growth) `
                    -Evidence @{ Database = $f.database_name; File = $f.name; Type = $f.type_desc; Growth = $f.growth; IsPercent = $f.is_percent_growth } `
                    -Recommendation 'Use deliberate fixed-size growth increments for most production databases.' -Source 'tsql')
            )
        }
    }

    $dbs = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Query "SELECT name FROM sys.databases WHERE state_desc='ONLINE' AND database_id > 4 ORDER BY name;"
    foreach ($db in $dbs) {
        try {
            $vlfRows = Invoke-StsQuery -SqlInstance $Context.InstanceName -SqlCredential $Context.SqlCredential -Database $db.name -Query "DBCC LOGINFO WITH NO_INFOMSGS;"
            $count = @($vlfRows).Count
            $state = if ($count -ge $vlfWarn) { 'Warning' } else { 'Info' }

            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'FileLayout' -Category 'VLF' -CheckId 'DB-VLF' -CheckName 'VLF count' `
                    -TargetType 'Database' -TargetName $db.name -InstanceName $Context.InstanceName -State $state -Severity 'Medium' -Weight 5 `
                    -Message ("Database {0} has {1} VLFs." -f $db.name, $count) `
                    -Evidence @{ Database = $db.name; VLFCount = $count; WarnThreshold = $vlfWarn } `
                    -Recommendation 'Excessive VLF counts can hurt recovery and log operations. Right-size log growth and consider corrective maintenance.' -Source 'dbcc')
            )
        } catch {
            $out.Add(
                (New-StsFinding -RunId $Context.RunId -Collector 'FileLayout' -Category 'VLF' -CheckId 'DB-VLF' -CheckName 'VLF count' `
                    -TargetType 'Database' -TargetName $db.name -InstanceName $Context.InstanceName -State 'Unknown' -Severity 'Medium' -Weight 5 `
                    -Message ("Could not inventory VLF count for {0}." -f $db.name) -Evidence @{} `
                    -Recommendation 'Review permissions and DBCC support on this version.' -Source 'dbcc')
            )
        }
    }

    $out
}
