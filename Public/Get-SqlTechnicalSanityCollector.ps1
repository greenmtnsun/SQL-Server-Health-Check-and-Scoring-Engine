
function Get-SqlTechnicalSanityCollector {
    [CmdletBinding()]
    param()

    Get-StsCheckRegistry |
        Group-Object Collector |
        ForEach-Object {
            [pscustomobject]@{
                Collector  = $_.Name
                CheckCount = $_.Count
                Checks     = ($_.Group.CheckId -join ', ')
            }
        }
}
