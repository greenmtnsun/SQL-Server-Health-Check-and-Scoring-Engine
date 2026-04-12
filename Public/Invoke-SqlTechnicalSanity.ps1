
function Invoke-SqlTechnicalSanity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$OutputDirectory = '.',
        [switch]$PassThru
    )

    $settings = Import-PowerShellDataFile -Path (Join-Path $script:ModuleRoot 'Config\Defaults.psd1')
    $run = Initialize-StsRun -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Settings $settings
    $registry = Get-StsCheckRegistry
    $allFindings = New-Object System.Collections.Generic.List[object]

    foreach ($instance in $SqlInstance) {
        $context = @{
            RunId         = $run.RunId
            InstanceName  = $instance
            SqlCredential = $SqlCredential
            Settings      = $settings.Thresholds
            HasDbatools   = $run.HasDbatools
        }

        foreach ($check in $registry) {
            $fn = Get-Command -Name $check.Function -ErrorAction SilentlyContinue
            if (-not $fn) {
                $allFindings.Add(
                    (New-StsFinding -RunId $run.RunId -Collector $check.Collector -Category $check.Category `
                        -CheckId $check.CheckId -CheckName $check.CheckName -TargetType 'Instance' -TargetName $instance `
                        -InstanceName $instance -State 'Unknown' -Severity 'High' -Weight $check.Weight `
                        -Message ("Collector function missing: {0}" -f $check.Function) -Evidence @{} `
                        -Recommendation 'Fix module packaging.' -Source 'engine')
                )
                continue
            }

            $collectorResult = Invoke-StsFailSoft -Check $check -Context $context -ScriptBlock {
                & $check.Function -Context $context -Check $check
            }

            foreach ($item in @($collectorResult)) {
                $allFindings.Add($item)
            }
        }
    }

    $score = Get-StsScores -Findings $allFindings.ToArray() -Settings $settings
    $html = ConvertTo-SqlTechnicalSanityHtml -Run $run -Findings $allFindings.ToArray() -Score $score
    $json = ConvertTo-SqlTechnicalSanityJson -Run $run -Findings $allFindings.ToArray() -Score $score
    $export = Export-SqlTechnicalSanityReport -Run $run -Html $html -Json $json -OutputDirectory $OutputDirectory

    if ($PassThru) {
        [pscustomobject]@{
            Run      = $run
            Findings = $allFindings.ToArray()
            Score    = $score
            HtmlPath = $export.HtmlPath
            JsonPath = $export.JsonPath
        }
    } else {
        $export
    }
}
