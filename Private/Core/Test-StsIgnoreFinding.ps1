function Test-StsIgnoreFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Finding,
        [Parameter(Mandatory)][object[]]$Rules
    )
    foreach ($rule in @($Rules)) {
        $matched = $true
        if ($rule.CheckId -and [string]$Finding.CheckId -ne [string]$rule.CheckId) { $matched = $false }
        if ($matched -and $rule.TargetName -and [string]$Finding.TargetName -ne [string]$rule.TargetName) { $matched = $false }
        if ($matched -and $rule.Collector -and [string]$Finding.Collector -ne [string]$rule.Collector) { $matched = $false }
        if ($matched -and $rule.State -and [string]$Finding.State -ne [string]$rule.State) { $matched = $false }
        if ($matched -and $rule.MatchText) {
            $hay = @([string]$Finding.Message,[string]$Finding.Recommendation,[string]($Finding.Evidence | Out-String)) -join ' '
            if ($hay -notmatch [regex]::Escape([string]$rule.MatchText)) { $matched = $false }
        }
        if ($matched -and $rule.Expires) {
            try {
                $expires = [datetime]$rule.Expires
                if ($expires -lt (Get-Date)) { $matched = $false }
            } catch { }
        }
        if ($matched) { return $rule }
    }
    $null
}
