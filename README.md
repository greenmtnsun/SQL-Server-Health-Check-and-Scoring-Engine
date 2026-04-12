
# SqlTechnicalSanity v6.2.1

This is a tightening pass on v6.2.

Changes:
- INST-CONNECT no longer relies on Connect-DbaInstance
- job collector handles no-history jobs without false critical failures
- FILELIST.txt added
- Test-SqlTechnicalSanityPackage added to verify all expected files are present

Goal:
- keep the working v6.2 framework
- reduce false positives
- make package completeness easy to verify
