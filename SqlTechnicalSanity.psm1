$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Get-ChildItem "$moduleRoot\Private\*.ps1" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
Get-ChildItem "$moduleRoot\Public\*.ps1" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
