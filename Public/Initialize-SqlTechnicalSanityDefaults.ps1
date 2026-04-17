# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function Initialize-SqlTechnicalSanityDefaults {
    [CmdletBinding()]
    param(
        [string]$ModuleRoot,
        [switch]$Force
    )

    if ([string]::IsNullOrWhiteSpace($ModuleRoot)) {
        $ModuleRoot = Split-Path -Parent $PSScriptRoot
    }

    $configDir = Join-Path $ModuleRoot 'Config'
    if (-not (Test-Path -LiteralPath $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $defaultsPath = Join-Path $configDir 'Defaults.psd1'
    $ignorePath   = Join-Path $configDir 'IgnoreRules.psd1'

    $defaultsContent = @'
@{
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
        Ignored  = 0
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
'@

    $ignoreContent = @'
@{
    Rules = @()
}
'@

    if ($Force -or -not (Test-Path -LiteralPath $defaultsPath)) {
        Set-Content -LiteralPath $defaultsPath -Value $defaultsContent -Encoding UTF8
    }

    if ($Force -or -not (Test-Path -LiteralPath $ignorePath)) {
        Set-Content -LiteralPath $ignorePath -Value $ignoreContent -Encoding UTF8
    }

    [pscustomobject]@{
        DefaultsPath    = $defaultsPath
        IgnoreRulesPath = $ignorePath
    }
}
