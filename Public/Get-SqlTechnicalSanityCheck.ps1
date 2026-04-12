
function Get-SqlTechnicalSanityCheck {
    [CmdletBinding()]
    param()

    Get-StsCheckRegistry | Select-Object Collector, Category, CheckId, CheckName, Weight, Function
}
