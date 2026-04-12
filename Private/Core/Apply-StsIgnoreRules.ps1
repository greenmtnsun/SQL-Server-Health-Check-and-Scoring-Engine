function Apply-StsIgnoreRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Findings,
        [Parameter(Mandatory)]$IgnoreConfig
    )
    $rules = @()
    if ($IgnoreConfig -and $IgnoreConfig.PSObject.Properties['Rules']) { $rules = @($IgnoreConfig.Rules) }
    if (@($rules).Count -eq 0) { return @($Findings) }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($f in @($Findings)) {
        $rule = Test-StsIgnoreFinding -Finding $f -Rules $rules
        if ($rule) {
            $clone = $f.PSObject.Copy()
            $clone | Add-Member -NotePropertyName Ignored -NotePropertyValue $true -Force
            $clone | Add-Member -NotePropertyName IgnoreReason -NotePropertyValue ([string]$rule.Reason) -Force
            $clone | Add-Member -NotePropertyName IgnoreOwner -NotePropertyValue ([string]$rule.Owner) -Force
            $clone | Add-Member -NotePropertyName IgnoreExpires -NotePropertyValue ([string]$rule.Expires) -Force
            $clone.State = 'Ignored'
            $clone.Severity = 'Info'
            $clone.Weight = 0
            $out.Add($clone)
        } else {
            if (-not $f.PSObject.Properties['Ignored']) { $f | Add-Member -NotePropertyName Ignored -NotePropertyValue $false -Force }
            $out.Add($f)
        }
    }
    @($out)
}
