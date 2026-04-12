
function ConvertTo-SqlTechnicalSanityJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Run,
        [Parameter(Mandatory)][object[]]$Findings,
        [Parameter(Mandatory)]$Score
    )

    [pscustomobject]@{
        schemaVersion = '6.2'
        run           = $Run
        score         = $Score
        findings      = $Findings
    } | ConvertTo-Json -Depth 10
}
