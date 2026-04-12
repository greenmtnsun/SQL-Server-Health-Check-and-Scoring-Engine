
function Initialize-StsRun {
    [CmdletBinding()]
    param(
        [string[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [hashtable]$Settings
    )

    $hasDbatools = $false
    $dbatoolsVersion = $null
    try {
        if (Get-Module -ListAvailable -Name dbatools) {
            Import-Module dbatools -ErrorAction Stop | Out-Null
            $hasDbatools = $true
            $dbatoolsVersion = (Get-Module dbatools | Select-Object -First 1).Version.ToString()
        }
    } catch {
        $hasDbatools = $false
    }

    [pscustomobject]@{
        RunId           = [guid]::NewGuid().Guid
        Instances       = $SqlInstance
        SqlCredential   = $SqlCredential
        Settings        = $Settings
        HasDbatools     = $hasDbatools
        DbatoolsVersion = $dbatoolsVersion
        GeneratedAt     = Get-Date
        HostName        = $env:COMPUTERNAME
        UserName        = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
}
