Import-Module .\SqlTechnicalSanity.psd1 -Force

Initialize-SqlTechnicalSanityDefaults -Force

$result = Invoke-SqlTechnicalSanity `
    -SqlInstance localhost `
    -OutputDirectory "C:\SYSADMIN\DATA" `
    -PassThru

$result.Score | Format-List
$result.HtmlPath
$result.JsonPath
