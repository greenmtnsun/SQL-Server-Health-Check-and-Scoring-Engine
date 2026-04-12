function Get-SqlTechnicalSanityIgnoreTemplate {
    [CmdletBinding()]
    param()
    [pscustomobject]@{
        Rules = @(
            @{
                CheckId    = 'BACKUP-LAST-LOG'
                TargetName = 'model'
                Reason     = 'Intentional in this environment'
                Owner      = $env:USERNAME
                Expires    = '2026-12-31'
            },
            @{
                CheckId   = 'ERRORLOG-SCAN'
                MatchText = 'SPN'
                Reason    = 'Accepted temporarily'
                Owner     = $env:USERNAME
            }
        )
    }
}
