function Invoke-StsCollectorInstance {
    New-StsFinding -CheckId "INSTANCE-UP" -TargetName "localhost" -State "Healthy" -Message "Instance responding"
}
