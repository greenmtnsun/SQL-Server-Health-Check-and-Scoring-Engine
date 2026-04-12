function Get-SqlTechnicalSanityTopActions {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='Path', Mandatory)][string]$JsonPath,
        [Parameter(ParameterSetName='Object', Mandatory)]$Data,
        [int]$Top = 3
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $JsonPath)) {
            throw "JSON path not found: $JsonPath"
        }
        $Data = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
    }

    $items = foreach ($f in @($Data.findings)) {
        $priority = 0

        if ($f.State -eq 'Critical') { $priority += 100 }
        elseif ($f.State -eq 'Warning') { $priority += 50 }

        if ($f.Severity -eq 'Critical') { $priority += 40 }
        elseif ($f.Severity -eq 'High') { $priority += 25 }
        elseif ($f.Severity -eq 'Medium') { $priority += 10 }

        $priority += [int]([double]$f.Weight)

        if ($priority -gt 0) {
            [pscustomobject]@{
                Priority       = $priority
                CheckId        = $f.CheckId
                TargetName     = $f.TargetName
                Message        = $f.Message
                Recommendation = $f.Recommendation
                State          = $f.State
            }
        }
    }

    @(
        $items |
        Sort-Object `
            @{Expression='Priority';Descending=$true}, `
            @{Expression='CheckId';Descending=$false}, `
            @{Expression='TargetName';Descending=$false} |
        Select-Object -First $Top
    )
}
