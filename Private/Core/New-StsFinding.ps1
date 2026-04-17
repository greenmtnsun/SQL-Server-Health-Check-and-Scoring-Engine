# STS:
# FileVersion: 1.0.0
# RequiresModuleVersion: 6.9.0

function New-StsFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$Collector,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$CheckId,
        [Parameter(Mandatory)][string]$CheckName,
        [Parameter(Mandatory)][string]$TargetType,
        [Parameter(Mandatory)][string]$TargetName,
        [Parameter(Mandatory)][string]$InstanceName,
        [ValidateSet('Healthy','Info','Warning','Critical','Unknown','Skipped','Ignored')]
        [string]$State,
        [ValidateSet('Info','Low','Medium','High','Critical')]
        [string]$Severity = 'Medium',
        [double]$Weight = 1,
        [string]$Message = '',
        [object]$Evidence = @{},
        [string]$Recommendation = 'None.',
        [object]$Source = 'engine',
        [int]$DurationMs = 0,
        [string]$ErrorId,
        [string]$ErrorMessage,
        $Raw
    )

    $Source = [string]$Source
    if ([string]::IsNullOrWhiteSpace($Source)) {
        $Source = 'engine'
    }

    $normalizedEvidence = @{}

    try {
        if ($null -eq $Evidence) {
            $normalizedEvidence = @{}
        }
        elseif ($Evidence -is [hashtable]) {
            foreach ($k in $Evidence.Keys) {
                $v = $Evidence[$k]
                if ($null -eq $v) {
                    $normalizedEvidence[$k] = $null
                }
                elseif ($v -is [datetime] -or
                        $v -is [string] -or
                        $v -is [bool] -or
                        $v -is [int] -or
                        $v -is [int64] -or
                        $v -is [double] -or
                        $v -is [decimal]) {
                    $normalizedEvidence[$k] = $v
                }
                else {
                    $normalizedEvidence[$k] = [string]$v
                }
            }
        }
        elseif ($Evidence -is [pscustomobject]) {
            foreach ($p in $Evidence.PSObject.Properties) {
                $v = $p.Value
                if ($null -eq $v) {
                    $normalizedEvidence[$p.Name] = $null
                }
                elseif ($v -is [datetime] -or
                        $v -is [string] -or
                        $v -is [bool] -or
                        $v -is [int] -or
                        $v -is [int64] -or
                        $v -is [double] -or
                        $v -is [decimal]) {
                    $normalizedEvidence[$p.Name] = $v
                }
                else {
                    $normalizedEvidence[$p.Name] = [string]$v
                }
            }
        }
        else {
            $normalizedEvidence = @{
                Value = [string]$Evidence
            }
        }
    }
    catch {
        $normalizedEvidence = @{
            EvidenceError = "Failed to normalize evidence"
            RawType       = $Evidence.GetType().FullName
        }
    }

    [pscustomobject]@{
        PSTypeName      = 'SqlTechnicalSanity.Finding'
        RunId           = $RunId
        ObservedAt      = [DateTimeOffset]::Now
        Collector       = $Collector
        Category        = $Category
        CheckId         = $CheckId
        CheckName       = $CheckName
        TargetType      = $TargetType
        TargetName      = $TargetName
        InstanceName    = $InstanceName
        State           = $State
        Severity        = $Severity
        Weight          = [double]$Weight
        Message         = $Message
        Evidence        = $normalizedEvidence
        Recommendation  = $Recommendation
        Source          = $Source
        DurationMs      = $DurationMs
        ErrorId         = $ErrorId
        ErrorMessage    = $ErrorMessage
        Raw             = $Raw
    }
}
