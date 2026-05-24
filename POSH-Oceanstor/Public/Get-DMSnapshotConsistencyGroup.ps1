function Get-DMSnapshotConsistencyGroup {
    <#
    .SYNOPSIS
        Retrieves Huawei OceanStor snapshot consistency groups.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 1)]
        [string]$Name
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $response = invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'SNAPSHOT_CONSISTENCY_GROUP' |
        Select-Object -ExpandProperty data
    $defaultDisplaySet = 'Id', 'Name', 'Protection Group Name', 'Running Status', 'Restore Speed', 'vStore Name'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $groups = [System.Collections.ArrayList]::new()

    foreach ($groupData in @($response)) {
        $group = [OceanstorSnapshotConsistencyGroup]::new($groupData, $session)
        if (-not $Name -or $group.Name -eq $Name) {
            $group | Add-Member MemberSet PSStandardMembers $standardMembers -Force
            [void]$groups.Add($group)
        }
    }

    return $groups
}
