
function Invoke-StsFailSoft {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Check,
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'

    try {
        $result = & $ScriptBlock
        if ($null -eq $result) {
            return New-StsFinding -RunId $Context.RunId -Collector $Check.Collector -Category $Check.Category `
                -CheckId $Check.CheckId -CheckName $Check.CheckName -TargetType 'Instance' -TargetName $Context.InstanceName `
                -InstanceName $Context.InstanceName -State 'Unknown' -Severity 'Medium' -Weight $Check.Weight `
                -Message 'Check returned no data.' -Evidence @{ Reason = 'null result' } `
                -Recommendation 'Review permissions, connectivity, and feature availability.' `
                -Source 'engine' -DurationMs $sw.ElapsedMilliseconds
        }

        foreach ($item in @($result)) {
            if ($item.PSTypeNames -contains 'SqlTechnicalSanity.Finding') {
                $item.DurationMs = [int]$sw.ElapsedMilliseconds
                $item
            } else {
                New-StsFinding -RunId $Context.RunId -Collector $Check.Collector -Category $Check.Category `
                    -CheckId $Check.CheckId -CheckName $Check.CheckName -TargetType 'Instance' -TargetName $Context.InstanceName `
                    -InstanceName $Context.InstanceName -State 'Info' -Severity 'Info' -Weight $Check.Weight `
                    -Message ([string]$item) -Evidence @{} -Recommendation 'None.' `
                    -Source 'engine' -DurationMs $sw.ElapsedMilliseconds
            }
        }
    } catch {
        New-StsFinding -RunId $Context.RunId -Collector $Check.Collector -Category $Check.Category `
            -CheckId $Check.CheckId -CheckName $Check.CheckName -TargetType 'Instance' -TargetName $Context.InstanceName `
            -InstanceName $Context.InstanceName -State 'Unknown' -Severity 'High' -Weight $Check.Weight `
            -Message ("Check failed: {0}" -f $Check.CheckId) -Evidence @{ ExceptionType = $_.Exception.GetType().FullName } `
            -Recommendation 'Review permissions, connectivity, module availability, and version support.' `
            -Source 'engine' -DurationMs $sw.ElapsedMilliseconds -ErrorId $_.FullyQualifiedErrorId -ErrorMessage $_.Exception.Message
    } finally {
        $ErrorActionPreference = $oldEap
        $sw.Stop()
    }
}
