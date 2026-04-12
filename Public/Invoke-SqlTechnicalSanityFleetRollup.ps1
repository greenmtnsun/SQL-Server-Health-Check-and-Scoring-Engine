function Invoke-SqlTechnicalSanityFleetRollup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$JsonFolder)
    $files = Get-ChildItem -LiteralPath $JsonFolder -Filter *.json -File | Sort-Object Name
    $rows = foreach ($f in $files) {
        try {
            $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
            [pscustomobject]@{
                File = $f.Name
                RunId = $j.run.RunId
                HostName = $j.run.HostName
                Instances = ($j.run.Instances -join ',')
                OverallScore = [double]$j.score.OverallScore
                CriticalCount = [int]$j.score.CriticalCount
                WarningCount = [int]$j.score.WarningCount
                UnknownCount = [int]$j.score.UnknownCount
                HealthyCount = [int]$j.score.HealthyCount
                InfoCount = [int]$j.score.InfoCount
                GeneratedAt = $j.run.GeneratedAt.DateTime
            }
        } catch {
            [pscustomobject]@{ File=$f.Name; RunId=$null; HostName=$null; Instances=$null; OverallScore=$null; CriticalCount=$null; WarningCount=$null; UnknownCount=$null; HealthyCount=$null; InfoCount=$null; GeneratedAt=$null }
        }
    }
    $rows
}
