
function Invoke-SqlTechnicalSanity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$OutputDirectory = '.',
        [switch]$PassThru,
        [string]$BaselineJsonPath
    )

    try {
        $settings = Get-StsSettings
    } catch {
        throw "Failed to load settings. $($_.Exception.Message)"
    }

    $run = Initialize-StsRun -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Settings $settings
    $registry = Get-StsCheckRegistry
    $allFindings = New-Object 'System.Collections.Generic.List[object]'

    foreach ($instance in $SqlInstance) {
        $context = @{
            RunId         = $run.RunId
            InstanceName  = $instance
            SqlCredential = $SqlCredential
            Settings      = $settings.Thresholds
            FullSettings  = $settings
            HasDbatools   = $run.HasDbatools
        }

        foreach ($check in $registry) {
            $fn = Get-Command -Name $check.Function -ErrorAction SilentlyContinue
            if (-not $fn) {
                $allFindings.Add(
                    (New-StsFinding `
                        -RunId $run.RunId `
                        -Collector $check.Collector `
                        -Category $check.Category `
                        -CheckId $check.CheckId `
                        -CheckName $check.CheckName `
                        -TargetType 'Instance' `
                        -TargetName $instance `
                        -InstanceName $instance `
                        -State 'Unknown' `
                        -Severity 'High' `
                        -Weight $check.Weight `
                        -Message "Collector function missing: $($check.Function)" `
                        -Evidence @{} `
                        -Recommendation 'Fix module packaging.' `
                        -Source 'engine')
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

    $findingsArray = @($allFindings.ToArray())

    $score = Get-StsScores -Findings $findingsArray -Settings $settings
    $html = ConvertTo-SqlTechnicalSanityHtml `
        -Run $run `
        -Findings $findingsArray `
        -Score $score `
        -BaselineJsonPath $BaselineJsonPath

    $json = ConvertTo-SqlTechnicalSanityJson `
        -Run $run `
        -Findings $findingsArray `
        -Score $score

    $export = Export-SqlTechnicalSanityReport `
        -Run $run `
        -Html $html `
        -Json $json `
        -OutputDirectory $OutputDirectory

    if ($PassThru) {
        [pscustomobject]@{
            Run      = $run
            Findings = $findingsArray
            Score    = $score
            HtmlPath = $export.HtmlPath
            JsonPath = $export.JsonPath
        }
    } else {
        $export
    }
}
