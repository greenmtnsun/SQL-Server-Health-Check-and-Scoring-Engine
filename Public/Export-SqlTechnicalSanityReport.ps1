
function Export-SqlTechnicalSanityReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Run,
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$Json,
        [string]$OutputDirectory = '.'
    )

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $htmlPath = Join-Path $OutputDirectory ("SqlTechnicalSanity-{0}.html" -f $stamp)
    $jsonPath = Join-Path $OutputDirectory ("SqlTechnicalSanity-{0}.json" -f $stamp)

    [System.IO.File]::WriteAllText($htmlPath, $Html, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($jsonPath, $Json, [System.Text.Encoding]::UTF8)

    [pscustomobject]@{
        HtmlPath = $htmlPath
        JsonPath = $jsonPath
        RunId    = $Run.RunId
    }
}
