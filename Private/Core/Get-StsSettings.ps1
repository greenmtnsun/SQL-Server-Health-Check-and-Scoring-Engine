function Get-StsSettings {
    [CmdletBinding()]
    param()

    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $defaultsPath = Join-Path $moduleRoot 'Config\Defaults.psd1'

    $fallback = @{
        Thresholds = @{
            FullBackupWarnHours         = 30
            FullBackupWarnDays          = 0
            DiffBackupWarnHours         = 18
            DiffBackupWarnDays          = 0
            LogBackupWarnMinutes        = 90
            LogBackupWarnHours          = 0
            DiskFreeWarnPct             = 15
            DiskFreeCritPct             = 8
            CertWarnDays                = 30
            CertCritDays                = 10
            JobFailureLookbackHrs       = 72
            TempDbFileCountWarn         = 4
            VlfWarnCount                = 300
            ErrorLogLookbackHours       = 72
            CpuRunnableWarn             = 12
            PLEWarn                     = 300
            FileGrowthPctWarn           = 25
            AgQueueWarnKb               = 262144
            LogShipLatencyWarnMinutes   = 60
            WaitPctWarn                 = 40
            ClusterNodeSkewWarn         = 1
            ClusterWeightedSkewWarnPct  = 35
            AgDbRedoQueueWarnKb         = 262144
            AgDbSendQueueWarnKb         = 262144
            AgNotHealthyWarnCount       = 1
            AgPrimarySkewWarnCount      = 2
        }
        StateScores = @{
            Healthy  = 1.00
            Info     = 0.95
            Warning  = 0.70
            Critical = 0.00
            Unknown  = 0.50
            Skipped  = 0.50
            Ignored  = $null
        }
        DomainWeights = @{
            Instance        = 1.0
            Databases       = 1.3
            Backups         = 1.7
            Jobs            = 1.1
            Performance     = 1.4
            Security        = 1.2
            Storage         = 1.2
            TempDb          = 1.2
            Replication     = 1.1
            HaDr            = 1.3
            Cluster         = 1.3
            AgIntelligence  = 1.2
            ErrorLog        = 1.0
            FileLayout      = 1.0
            Shares          = 1.0
        }
    }

    $data = $fallback
    if (Test-Path -LiteralPath $defaultsPath) {
        try {
            $loaded = Import-PowerShellDataFile -LiteralPath $defaultsPath
            if ($loaded) {
                $data = $loaded
            }
        } catch {
            $data = $fallback
        }
    }

    if (-not $data.ContainsKey('Thresholds')) { $data.Thresholds = $fallback.Thresholds }
    if (-not $data.ContainsKey('StateScores')) { $data.StateScores = $fallback.StateScores }
    if (-not $data.ContainsKey('DomainWeights')) { $data.DomainWeights = $fallback.DomainWeights }

    [pscustomobject]@{
        Thresholds    = $data.Thresholds
        StateScores   = $data.StateScores
        DomainWeights = $data.DomainWeights
    }
}
