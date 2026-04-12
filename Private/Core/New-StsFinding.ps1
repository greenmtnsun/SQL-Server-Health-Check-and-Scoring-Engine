function New-StsFinding {
    param(
        [string]$CheckId,
        [string]$TargetName,
        [string]$State,
        [double]$Weight = 1,
        [string]$Message = ''
    )

    [pscustomobject]@{
        CheckId = $CheckId
        TargetName = $TargetName
        State = $State
        Weight = $Weight
        Message = $Message
        Collector = "General"
    }
}
