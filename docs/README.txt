SqlTechnicalSanity v6.8.2

This release fixes the two remaining wiring issues from the last run:

1. Bootstrap export
- Initialize-SqlTechnicalSanityDefaults is now exported from:
  - SqlTechnicalSanity.psd1
  - SqlTechnicalSanity.psm1

2. Example baseline rendering
- Example-Run.ps1 now:
  - runs the compare against $result.JsonPath
  - regenerates the HTML using ConvertTo-SqlTechnicalSanityHtml with -BaselineJsonPath
  - writes the updated HTML back to $result.HtmlPath

Files included
--------------
- SqlTechnicalSanity.psd1
- SqlTechnicalSanity.psm1
- Example-Run.ps1
