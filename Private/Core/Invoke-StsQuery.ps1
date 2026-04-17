# STS:
# FileVersion: 1.0.1
# RequiresModuleVersion: 6.9.0

function Invoke-StsQuery {
    [CmdletBinding(DefaultParameterSetName='ByContext')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByContext')]
        $Context,

        [Parameter(Mandatory=$true, ParameterSetName='ByDirect')]
        [string]$SqlInstance,

        [Parameter(ParameterSetName='ByDirect')]
        [PSCredential]$SqlCredential,

        [Parameter(Mandatory=$true)]
        [string]$Query,

        [string]$Database = 'master'
    )

    if (-not (Get-Command Invoke-DbaQuery -ErrorAction SilentlyContinue)) {
        throw "Invoke-DbaQuery is required. Install dbatools or add an ADO.NET fallback to Invoke-StsQuery."
    }

    $resolvedInstance = $null
    $resolvedCredential = $null

    if ($PSCmdlet.ParameterSetName -eq 'ByContext') {
        if (-not $Context) { throw "Context is required." }
        $resolvedInstance = [string]$Context.InstanceName
        if ($Context.PSObject.Properties['SqlCredential']) {
            $resolvedCredential = $Context.SqlCredential
        }
    }
    else {
        $resolvedInstance = [string]$SqlInstance
        $resolvedCredential = $SqlCredential
    }

    if ([string]::IsNullOrWhiteSpace($resolvedInstance)) {
        throw "SqlInstance could not be resolved."
    }

    $invokeParams = @{
        SqlInstance     = $resolvedInstance
        Query           = $Query
        Database        = $Database
        EnableException = $true
    }

    if ($null -ne $resolvedCredential) {
        $invokeParams.SqlCredential = $resolvedCredential
    }

    Invoke-DbaQuery @invokeParams
}
