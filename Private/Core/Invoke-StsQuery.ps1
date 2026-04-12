
function Invoke-StsQuery {
    [CmdletBinding()]
    param(
        [string]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$Query,
        [string]$Database = 'master'
    )

    if (-not (Get-Command Invoke-DbaQuery -ErrorAction SilentlyContinue)) {
        throw "Invoke-DbaQuery is required in this scaffold version. Install dbatools or add an ADO.NET fallback to Invoke-StsQuery."
    }

    $server = $null
    if (Get-Command Connect-DbaInstance -ErrorAction SilentlyContinue) {
        try {
            $connectParams = @{
                SqlInstance = $SqlInstance
                TrustServerCertificate = $true
            }
            if ($SqlCredential) { $connectParams.SqlCredential = $SqlCredential }
            $server = Connect-DbaInstance @connectParams
        } catch {
            $server = $null
        }
    }

    $params = @{
        Query           = $Query
        Database        = $Database
        As              = 'PSObject'
        EnableException = $true
    }

    if ($server) {
        $params.SqlInstance = $server
    } else {
        $params.SqlInstance = $SqlInstance
        $params.TrustServerCertificate = $true
        if ($SqlCredential) { $params.SqlCredential = $SqlCredential }
    }

    Invoke-DbaQuery @params
}
