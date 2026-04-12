[CmdletBinding(DefaultParameterSetName='Interactive')]
param(
    [Parameter(ParameterSetName='Interactive')]
    [switch]$Interactive,

    [Parameter(ParameterSetName='Threshold')]
    [ValidateSet(
        'FullBackupWarnHours','FullBackupWarnDays',
        'DiffBackupWarnHours','DiffBackupWarnDays',
        'LogBackupWarnMinutes','LogBackupWarnHours',
        'DiskFreeWarnPct','DiskFreeCritPct',
        'CertWarnDays','CertCritDays',
        'JobFailureLookbackHrs',
        'TempDbFileCountWarn','VlfWarnCount',
        'ErrorLogLookbackHours',
        'CpuRunnableWarn','PLEWarn',
        'FileGrowthPctWarn',
        'AgQueueWarnKb','LogShipLatencyWarnMinutes',
        'WaitPctWarn',
        'ClusterNodeSkewWarn','ClusterWeightedSkewWarnPct',
        'AgDbRedoQueueWarnKb','AgDbSendQueueWarnKb',
        'AgNotHealthyWarnCount','AgPrimarySkewWarnCount'
    )]
    [string]$ThresholdName,

    [Parameter(ParameterSetName='Threshold')]
    [double]$ThresholdValue,

    [Parameter(ParameterSetName='Ignore')]
    [switch]$AddIgnoreRule,

    [Parameter(ParameterSetName='Ignore')] [string]$CheckId,
    [Parameter(ParameterSetName='Ignore')] [string]$TargetName,
    [Parameter(ParameterSetName='Ignore')] [string]$Collector,
    [Parameter(ParameterSetName='Ignore')] [string]$State,
    [Parameter(ParameterSetName='Ignore')] [string]$MatchText,
    [Parameter(ParameterSetName='Ignore')] [string]$Reason,
    [Parameter(ParameterSetName='Ignore')] [string]$Owner,
    [Parameter(ParameterSetName='Ignore')] [string]$Expires,

    [Parameter(ParameterSetName='RemoveIgnore')]
    [switch]$RemoveIgnoreRule,

    [Parameter(ParameterSetName='RemoveIgnore')]
    [int]$IgnoreIndex = -1,

    [Parameter()] [string]$ThresholdsPath = ".\Config\Defaults.psd1",
    [Parameter()] [string]$IgnoreRulesPath = ".\Config\IgnoreRules.psd1",
    [Parameter()] [switch]$ShowOnly
)

Set-StrictMode -Version 2.0

function Get-StsDefaultThresholds {
    [ordered]@{
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
}

function Get-StsDefaultIgnoreConfig { @{ Rules = @() } }

function Import-StsDataFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$DefaultObject
    )
    if (Test-Path -LiteralPath $Path) {
        try { return Import-PowerShellDataFile -LiteralPath $Path }
        catch { throw "Could not read config file '$Path'. $($_.Exception.Message)" }
    }
    return $DefaultObject
}

function Ensure-StsParentFolder {
    param([Parameter(Mandatory)][string]$Path)
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Convert-ValueToPsd1Literal {
    param([Parameter(Mandatory)]$Value)
    if ($null -eq $Value) { return '$null' }
    if ($Value -is [bool]) { if ($Value) { return '$true' } else { return '$false' } }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return [string]$Value }
    $escaped = [string]$Value -replace "'", "''"
    return "'$escaped'"
}

function Export-StsThresholdsFile {
    param(
        [Parameter(Mandatory)][hashtable]$Thresholds,
        [Parameter(Mandatory)][string]$Path
    )
    Ensure-StsParentFolder -Path $Path
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('@{')
    $lines.Add('    Thresholds = @{')
    foreach ($key in $Thresholds.Keys) {
        $value = Convert-ValueToPsd1Literal -Value $Thresholds[$key]
        $lines.Add("        $key = $value")
    }
    $lines.Add('    }')
    $lines.Add('}')
    Set-Content -LiteralPath $Path -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

function Export-StsIgnoreRulesFile {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rules,
        [Parameter(Mandatory)][string]$Path
    )
    Ensure-StsParentFolder -Path $Path
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('@{')
    $lines.Add('    Rules = @(')
    foreach ($rule in @($Rules)) {
        $lines.Add('        @{')
        foreach ($prop in @('CheckId','TargetName','Collector','State','MatchText','Reason','Owner','Expires')) {
            $value = $rule.$prop
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                $literal = Convert-ValueToPsd1Literal -Value $value
                $lines.Add("            $prop = $literal")
            }
        }
        $lines.Add('        }')
    }
    $lines.Add('    )')
    $lines.Add('}')
    Set-Content -LiteralPath $Path -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

function Show-StsThresholds {
    param([Parameter(Mandatory)][hashtable]$Thresholds)
    "Thresholds"
    "----------"
    foreach ($key in $Thresholds.Keys) {
        "{0,-28} {1}" -f $key, $Thresholds[$key]
    }
}

function Show-StsIgnoreRules {
    param([AllowEmptyCollection()][object[]]$Rules)
    "Ignore Rules"
    "------------"
    if (@($Rules).Count -eq 0) {
        "[none]"
        return
    }
    for ($i = 0; $i -lt $Rules.Count; $i++) {
        $r = $Rules[$i]
        "[{0}] CheckId={1}; TargetName={2}; Collector={3}; State={4}; MatchText={5}; Reason={6}; Owner={7}; Expires={8}" -f $i, $r.CheckId, $r.TargetName, $r.Collector, $r.State, $r.MatchText, $r.Reason, $r.Owner, $r.Expires
    }
}

function Read-StsPrompt {
    param([Parameter(Mandatory)][string]$Prompt,[string]$Default)
    if ([string]::IsNullOrWhiteSpace($Default)) { return (Read-Host $Prompt) }
    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}

function Invoke-StsInteractiveThresholdEditor {
    param(
        [Parameter(Mandatory)][hashtable]$Thresholds,
        [Parameter(Mandatory)][string]$Path
    )
    while ($true) {
        ""
        Show-StsThresholds -Thresholds $Thresholds
        ""
        $name = Read-Host "Enter threshold name to change, LIST, SAVE, or BACK"
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        switch ($name.ToUpperInvariant()) {
            'BACK' { return }
            'LIST' { continue }
            'SAVE' {
                Export-StsThresholdsFile -Thresholds $Thresholds -Path $Path
                "Saved thresholds to $Path"
                continue
            }
            default {
                if (-not $Thresholds.Contains($name)) {
                    "Unknown threshold: $name"
                    continue
                }
                $newValueText = Read-Host "New value for $name"
                [double]$newValue = 0
                if (-not [double]::TryParse($newValueText, [ref]$newValue)) {
                    "Invalid number."
                    continue
                }
                $Thresholds[$name] = $newValue
                "$name updated."
            }
        }
    }
}

function Invoke-StsInteractiveIgnoreEditor {
    param(
        [AllowEmptyCollection()][System.Collections.ArrayList]$Rules,
        [Parameter(Mandatory)][string]$Path
    )
    while ($true) {
        ""
        Show-StsIgnoreRules -Rules @($Rules)
        ""
        $cmd = Read-Host "ADD, REMOVE, SAVE, BACK"
        if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
        switch ($cmd.ToUpperInvariant()) {
            'BACK' { return }
            'SAVE' {
                Export-StsIgnoreRulesFile -Rules @($Rules) -Path $Path
                "Saved ignore rules to $Path"
            }
            'REMOVE' {
                if ($Rules.Count -eq 0) {
                    "There are no rules to remove."
                    continue
                }
                $idxText = Read-Host "Index to remove"
                [int]$idx = -1
                if (-not [int]::TryParse($idxText, [ref]$idx)) {
                    "Invalid index."
                    continue
                }
                if ($idx -lt 0 -or $idx -ge $Rules.Count) {
                    "Index out of range."
                    continue
                }
                $Rules.RemoveAt($idx)
                "Rule removed."
            }
            'ADD' {
                $rule = [ordered]@{}
                $rule.CheckId    = Read-StsPrompt -Prompt "CheckId"
                $rule.TargetName = Read-StsPrompt -Prompt "TargetName"
                $rule.Collector  = Read-StsPrompt -Prompt "Collector"
                $rule.State      = Read-StsPrompt -Prompt "State"
                $rule.MatchText  = Read-StsPrompt -Prompt "MatchText"
                $rule.Reason     = Read-StsPrompt -Prompt "Reason"
                $rule.Owner      = Read-StsPrompt -Prompt "Owner" -Default $env:USERNAME
                $rule.Expires    = Read-StsPrompt -Prompt "Expires (yyyy-mm-dd)"
                [void]$Rules.Add([pscustomobject]$rule)
                "Rule added."
            }
            default {
                "Unknown command."
            }
        }
    }
}

$thresholdData = Import-StsDataFile -Path $ThresholdsPath -DefaultObject @{ Thresholds = (Get-StsDefaultThresholds) }
$ignoreData = Import-StsDataFile -Path $IgnoreRulesPath -DefaultObject (Get-StsDefaultIgnoreConfig)

$thresholds = Get-StsDefaultThresholds
if ($thresholdData -and $thresholdData.ContainsKey('Thresholds')) {
    foreach ($key in $thresholdData.Thresholds.Keys) {
        $thresholds[$key] = $thresholdData.Thresholds[$key]
    }
}

$rulesList = [System.Collections.ArrayList]::new()
foreach ($rule in @($ignoreData.Rules)) {
    [void]$rulesList.Add([pscustomobject]$rule)
}

if ($ShowOnly) {
    Show-StsThresholds -Thresholds $thresholds
    ""
    Show-StsIgnoreRules -Rules @($rulesList)
    return
}

switch ($PSCmdlet.ParameterSetName) {
    'Threshold' {
        $thresholds[$ThresholdName] = $ThresholdValue
        Export-StsThresholdsFile -Thresholds $thresholds -Path $ThresholdsPath
        Show-StsThresholds -Thresholds $thresholds
        return
    }
    'Ignore' {
        $rule = [pscustomobject]@{
            CheckId    = $CheckId
            TargetName = $TargetName
            Collector  = $Collector
            State      = $State
            MatchText  = $MatchText
            Reason     = $Reason
            Owner      = if ([string]::IsNullOrWhiteSpace($Owner)) { $env:USERNAME } else { $Owner }
            Expires    = $Expires
        }
        [void]$rulesList.Add($rule)
        Export-StsIgnoreRulesFile -Rules @($rulesList) -Path $IgnoreRulesPath
        Show-StsIgnoreRules -Rules @($rulesList)
        return
    }
    'RemoveIgnore' {
        if ($IgnoreIndex -lt 0 -or $IgnoreIndex -ge $rulesList.Count) {
            throw "IgnoreIndex is out of range."
        }
        $rulesList.RemoveAt($IgnoreIndex)
        Export-StsIgnoreRulesFile -Rules @($rulesList) -Path $IgnoreRulesPath
        Show-StsIgnoreRules -Rules @($rulesList)
        return
    }
    default {
        while ($true) {
            ""
            "SqlTechnicalSanity Config Manager"
            "1. Edit thresholds"
            "2. Edit ignore rules"
            "3. Show current config"
            "4. Save both files"
            "5. Exit"
            $choice = Read-Host "Choose 1-5"
            switch ($choice) {
                '1' { Invoke-StsInteractiveThresholdEditor -Thresholds $thresholds -Path $ThresholdsPath }
                '2' { Invoke-StsInteractiveIgnoreEditor -Rules $rulesList -Path $IgnoreRulesPath }
                '3' {
                    ""
                    Show-StsThresholds -Thresholds $thresholds
                    ""
                    Show-StsIgnoreRules -Rules @($rulesList)
                }
                '4' {
                    Export-StsThresholdsFile -Thresholds $thresholds -Path $ThresholdsPath
                    Export-StsIgnoreRulesFile -Rules @($rulesList) -Path $IgnoreRulesPath
                    "Saved both config files."
                }
                '5' { break }
                default { "Unknown choice." }
            }
        }
    }
}
