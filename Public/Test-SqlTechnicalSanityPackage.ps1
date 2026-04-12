
function Test-SqlTechnicalSanityPackage {
    [CmdletBinding()]
    param()

    $requiredFiles = @(
        'SqlTechnicalSanity.psm1',
        'SqlTechnicalSanity.psd1',
        'Config\Defaults.psd1',
        'Private\Core\New-StsFinding.ps1',
        'Private\Core\Initialize-StsRun.ps1',
        'Private\Core\Invoke-StsFailSoft.ps1',
        'Private\Core\Invoke-StsQuery.ps1',
        'Private\Core\Get-StsCheckRegistry.ps1',
        'Private\Core\Get-StsScores.ps1',
        'Public\Invoke-SqlTechnicalSanity.ps1',
        'Public\ConvertTo-SqlTechnicalSanityHtml.ps1',
        'Public\ConvertTo-SqlTechnicalSanityJson.ps1',
        'Public\Export-SqlTechnicalSanityReport.ps1',
        'Public\Get-SqlTechnicalSanityCollector.ps1',
        'Public\Get-SqlTechnicalSanityCheck.ps1',
        'Public\Test-SqlTechnicalSanityPackage.ps1',
        'Private\Collectors\Instance.Collector.ps1',
        'Private\Collectors\Databases.Collector.ps1',
        'Private\Collectors\Backups.Collector.ps1',
        'Private\Collectors\Jobs.Collector.ps1',
        'Private\Collectors\HaDr.Collector.ps1',
        'Private\Collectors\Storage.Collector.ps1',
        'Private\Collectors\Security.Collector.ps1',
        'Private\Collectors\Performance.Collector.ps1',
        'Private\Collectors\Replication.Collector.ps1',
        'Private\Collectors\TempDb.Collector.ps1',
        'Private\Collectors\ErrorLog.Collector.ps1',
        'Private\Collectors\Shares.Collector.ps1',
        'Private\Collectors\FileLayout.Collector.ps1',
        'README.md',
        'Example-Run.ps1',
        'FILELIST.txt'
    )

    $root = Split-Path -Parent $script:ModuleRoot
    $missing = foreach ($f in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $script:ModuleRoot $f))) { $f }
    }

    [pscustomobject]@{
        ModuleRoot    = $script:ModuleRoot
        RequiredCount = $requiredFiles.Count
        MissingCount  = @($missing).Count
        MissingFiles  = @($missing)
        Passed        = (@($missing).Count -eq 0)
    }
}
