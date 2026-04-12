
function Invoke-StsCollectorCluster {
    [CmdletBinding()]
    param([hashtable]$Context, [hashtable]$Check)

    $nodeSkewWarn = [int]$Context.Settings.ClusterNodeSkewWarn
    $weightedSkewWarnPct = [int]$Context.Settings.ClusterWeightedSkewWarnPct

    if (-not (Get-Module -ListAvailable -Name FailoverClusters)) {
        return New-StsFinding -RunId $Context.RunId -Collector 'Cluster' -Category 'Cluster' -CheckId 'CLUSTER-BALANCE' -CheckName 'Cluster owner and balance' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Info' -Severity 'Info' -Weight 2 `
            -Message 'FailoverClusters module not available on this host.' -Evidence @{} -Recommendation 'None.' -Source 'powershell'
    }

    Import-Module FailoverClusters -ErrorAction Stop | Out-Null

    try {
        $nodes = @(Get-ClusterNode | Select-Object Name, State)
    } catch {
        return New-StsFinding -RunId $Context.RunId -Collector 'Cluster' -Category 'Cluster' -CheckId 'CLUSTER-BALANCE' -CheckName 'Cluster owner and balance' `
            -TargetType 'Instance' -TargetName $Context.InstanceName -InstanceName $Context.InstanceName -State 'Info' -Severity 'Info' -Weight 2 `
            -Message 'Cluster cmdlets available, but this server does not appear to be an active cluster node context.' -Evidence @{} -Recommendation 'None.' -Source 'powershell'
    }

    $sqlResources = @(
        Get-ClusterResource -ErrorAction Stop |
        Where-Object { $_.ResourceType -match '^SQL Server$|^SQL Server Agent$|^SQL IP Address$|^SQL Network Name$' }
    )

    $sqlServerResources = @($sqlResources | Where-Object ResourceType -eq 'SQL Server')

    if (-not $sqlServerResources) {
        return New-StsFinding -RunId $Context.RunId -Collector 'Cluster' -Category 'Cluster' -CheckId 'CLUSTER-BALANCE' -CheckName 'Cluster owner and balance' `
            -TargetType 'Cluster' -TargetName ($env:COMPUTERNAME) -InstanceName $Context.InstanceName -State 'Info' -Severity 'Info' -Weight 3 `
            -Message 'Cluster detected, but no clustered SQL Server resources were found.' -Evidence @{ NodeCount = @($nodes).Count } -Recommendation 'None.' -Source 'powershell'
    }

    $groupMap = @()
    foreach ($res in $sqlServerResources) {
        $group = $res.OwnerGroup
        $groupName = if ($group -is [string]) { $group } else { $group.Name }
        try {
            $g = Get-ClusterGroup -Name $groupName -ErrorAction Stop
            $ownerNode = if ($g.OwnerNode) { $g.OwnerNode.Name } else { $null }
            $weight = 1
            $groupMap += [pscustomobject]@{
                SqlResource = $res.Name
                GroupName   = $groupName
                OwnerNode   = $ownerNode
                State       = $g.State
                Weight      = $weight
            }
        } catch { }
    }

    if (-not $groupMap) {
        return New-StsFinding -RunId $Context.RunId -Collector 'Cluster' -Category 'Cluster' -CheckId 'CLUSTER-BALANCE' -CheckName 'Cluster owner and balance' `
            -TargetType 'Cluster' -TargetName ($env:COMPUTERNAME) -InstanceName $Context.InstanceName -State 'Unknown' -Severity 'Medium' -Weight 4 `
            -Message 'Could not map clustered SQL resources to owner groups.' -Evidence @{} -Recommendation 'Review cluster group/resource visibility.' -Source 'powershell'
    }

    $countsByNode = $groupMap | Group-Object OwnerNode | ForEach-Object {
        [pscustomobject]@{
            Node = $_.Name
            Count = $_.Count
            Weight = ($_.Group | Measure-Object Weight -Sum).Sum
        }
    }

    $allUpNodes = @($nodes | Where-Object State -eq 'Up')
    $maxCount = ($countsByNode | Measure-Object Count -Maximum).Maximum
    $minCount = ($countsByNode | Measure-Object Count -Minimum).Minimum
    if ($null -eq $minCount) { $minCount = 0 }
    $skew = [int]$maxCount - [int]$minCount

    $totalWeight = ($countsByNode | Measure-Object Weight -Sum).Sum
    $avgWeight = if (@($allUpNodes).Count -gt 0) { [double]$totalWeight / [double]@($allUpNodes).Count } else { 0 }
    $maxWeight = ($countsByNode | Measure-Object Weight -Maximum).Maximum
    $weightSkewPct = if ($avgWeight -gt 0) { [math]::Round((([double]$maxWeight - [double]$avgWeight) / [double]$avgWeight) * 100, 1) } else { 0 }

    $state = 'Healthy'
    if ($skew -gt $nodeSkewWarn -or $weightSkewPct -gt $weightedSkewWarnPct) {
        $state = 'Warning'
    }

    $mapping = ($groupMap | Sort-Object OwnerNode, GroupName | ForEach-Object { "{0}->{1}" -f $_.GroupName, $_.OwnerNode }) -join '; '
    $countSummary = ($countsByNode | Sort-Object Node | ForEach-Object { "{0}:{1}" -f $_.Node, $_.Count }) -join '; '

    @(
        (New-StsFinding -RunId $Context.RunId -Collector 'Cluster' -Category 'Cluster' -CheckId 'CLUSTER-BALANCE' -CheckName 'Cluster owner and balance' `
            -TargetType 'Cluster' -TargetName $env:COMPUTERNAME -InstanceName $Context.InstanceName -State $state -Severity 'Medium' -Weight 9 `
            -Message ("Cluster SQL owner skew is {0}; weighted skew is {1}%." -f $skew, $weightSkewPct) `
            -Evidence @{ UpNodes = @($allUpNodes).Count; SqlGroups = @($groupMap).Count; CountByNode = $countSummary; Mapping = $mapping; NodeSkew = $skew; NodeSkewWarn = $nodeSkewWarn; WeightedSkewPct = $weightSkewPct; WeightedSkewWarnPct = $weightedSkewWarnPct } `
            -Recommendation 'Spread clustered SQL groups more evenly across available nodes when practical.' -Source 'powershell')
    )
}
