
function Get-StsCheckRegistry {
    [CmdletBinding()]
    param()

    @(
        @{ Collector='Instance';       Category='Instance';         CheckId='INST-CONNECT';        CheckName='Instance connectivity';             Weight=10; Function='Invoke-StsCollectorInstance' },
        @{ Collector='Databases';      Category='Databases';        CheckId='DB-STATE';            CheckName='Database state';                    Weight=10; Function='Invoke-StsCollectorDatabases' },
        @{ Collector='Backups';        Category='Backups';          CheckId='BACKUP-LAST';         CheckName='Backup freshness';                  Weight=10; Function='Invoke-StsCollectorBackups' },
        @{ Collector='Jobs';           Category='Jobs';             CheckId='JOB-FAILURES';        CheckName='Agent job health';                  Weight=8;  Function='Invoke-StsCollectorJobs' },
        @{ Collector='HaDr';           Category='HaDr';             CheckId='HADR-CORE';           CheckName='HA/DR core status';                 Weight=10; Function='Invoke-StsCollectorHaDr' },
        @{ Collector='AgIntelligence'; Category='AgIntelligence';   CheckId='AG-DB-SYNC';          CheckName='AG database sync detail';           Weight=10; Function='Invoke-StsCollectorAgIntelligence' },
        @{ Collector='Cluster';        Category='Cluster';          CheckId='CLUSTER-BALANCE';     CheckName='Cluster owner and balance';         Weight=9;  Function='Invoke-StsCollectorCluster' },
        @{ Collector='Storage';        Category='Storage';          CheckId='DISK-FREE';           CheckName='Disk free space';                   Weight=9;  Function='Invoke-StsCollectorStorage' },
        @{ Collector='Security';       Category='Security';         CheckId='CERT-EXPIRY';         CheckName='Certificate expiry';                Weight=6;  Function='Invoke-StsCollectorSecurity' },
        @{ Collector='Performance';    Category='Performance';      CheckId='PERF-SNAPSHOT';       CheckName='Blocking, waits, and pressure';     Weight=10; Function='Invoke-StsCollectorPerformance' },
        @{ Collector='Replication';    Category='Replication';      CheckId='REPL-SUMMARY';        CheckName='Replication summary';               Weight=9;  Function='Invoke-StsCollectorReplication' },
        @{ Collector='TempDb';         Category='TempDb';           CheckId='TEMPDB-FILES';        CheckName='TempDB layout';                     Weight=7;  Function='Invoke-StsCollectorTempDb' },
        @{ Collector='ErrorLog';       Category='ErrorLog';         CheckId='ERRORLOG-SCAN';       CheckName='Error log scan';                    Weight=6;  Function='Invoke-StsCollectorErrorLog' },
        @{ Collector='Shares';         Category='Shares';           CheckId='SHARE-PATHS';         CheckName='UNC path validation';               Weight=7;  Function='Invoke-StsCollectorShares' },
        @{ Collector='FileLayout';     Category='FileLayout';       CheckId='FILES-GROWTH-VLF';    CheckName='File growth and VLF risk';          Weight=9;  Function='Invoke-StsCollectorFileLayout' }
    )
}
