@{
    RootModule        = 'SqlTechnicalSanity.psm1'
    ModuleVersion = '6.9.0'
    GUID              = '5d6dd4e6-1401-4aaf-8f57-75da4b2626b8'
    Author            = 'OpenAI'
    CompanyName       = 'OpenAI'
    Copyright         = '(c) OpenAI'
    Description       = 'SqlTechnicalSanity v6.8.2 fixes bootstrap export and example baseline rendering.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Invoke-SqlTechnicalSanity',
        'Invoke-SqlTechnicalSanityWithPolicy',
        'Get-SqlTechnicalSanityCollector',
        'Get-SqlTechnicalSanityCheck',
        'ConvertTo-SqlTechnicalSanityHtml',
        'ConvertTo-SqlTechnicalSanityJson',
        'Export-SqlTechnicalSanityReport',
        'Test-SqlTechnicalSanityPackage',
        'Compare-SqlTechnicalSanityBaseline',
        'Get-SqlTechnicalSanityExecutiveSummary',
        'Invoke-SqlTechnicalSanityFleetRollup',
        'Export-SqlTechnicalSanityFleetRollupHtml',
        'Get-SqlTechnicalSanityTopActions',
        'Get-SqlTechnicalSanityThresholds',
        'Get-SqlTechnicalSanityIgnoreTemplate',
        'Initialize-SqlTechnicalSanityDefaults'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Prerelease = ''
            ProjectUri = 'https://github.com/'
            Tags = @('SQLServer','HealthCheck','PowerShell')
        }
    }

}
