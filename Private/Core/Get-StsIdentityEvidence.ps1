function Get-StsIdentityEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context
    )

    @{
        InstanceName        = $Context.InstanceName
        SqlInstanceFullName = $Context.SqlInstanceFullName
    }
}
