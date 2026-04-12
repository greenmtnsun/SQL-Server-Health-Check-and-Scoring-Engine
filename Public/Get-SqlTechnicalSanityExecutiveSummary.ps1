function Get-SqlTechnicalSanityExecutiveSummary {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='Path', Mandatory)][string]$JsonPath,
        [Parameter(ParameterSetName='Object', Mandatory)]$Data
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $JsonPath)) { throw "JSON path not found: $JsonPath" }
        $Data = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
    }

    $findings = @($Data.findings | Where-Object State -ne 'Ignored')
    $alerts = @($findings | Where-Object State -eq 'Critical'; $findings | Where-Object State -eq 'Warning') | Select-Object -First 5
    $summary = @()
    $summary += "Overall score: $($Data.score.OverallScore)"
    $summary += "Critical: $($Data.score.CriticalCount), Warning: $($Data.score.WarningCount), Unknown: $($Data.score.UnknownCount)"
    if ($Data.score.PSObject.Properties['IgnoredCount']) { $summary += "Ignored: $($Data.score.IgnoredCount)" }
    if (@($alerts).Count -gt 0) {
        $summary += ("Top items: " + (($alerts | ForEach-Object { "$($_.CheckId) [$($_.State)] $($_.TargetName)" }) -join '; '))
    } else {
        $summary += "No critical or warning findings."
    }

    [pscustomobject]@{
        RunId         = $Data.run.RunId
        OverallScore  = [double]$Data.score.OverallScore
        CriticalCount = [int]$Data.score.CriticalCount
        WarningCount  = [int]$Data.score.WarningCount
        UnknownCount  = [int]$Data.score.UnknownCount
        HealthyCount  = [int]$Data.score.HealthyCount
        InfoCount     = [int]$Data.score.InfoCount
        IgnoredCount  = if ($Data.score.PSObject.Properties['IgnoredCount']) { [int]$Data.score.IgnoredCount } else { 0 }
        TopItems      = @($alerts)
        Summary       = $summary
    }
}
