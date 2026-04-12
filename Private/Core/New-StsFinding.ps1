
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
        [ValidateSet('Healthy','Info','Warning','Critical','Unknown','Skipped')]
        [string]$State,
        [ValidateSet('Info','Low','Medium','High','Critical')]
        [string]$Severity = 'Medium',
        [double]$Weight = 1,
        [string]$Message = '',
        [hashtable]$Evidence = @{},
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
        Evidence        = $Evidence
        Recommendation  = $Recommendation
        Source          = $Source
        DurationMs      = $DurationMs
        ErrorId         = $ErrorId
        ErrorMessage    = $ErrorMessage
        Raw             = $Raw
    }
}
