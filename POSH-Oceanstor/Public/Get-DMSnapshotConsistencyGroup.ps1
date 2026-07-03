function Get-DMSnapshotConsistencyGroup {
    <#
    .SYNOPSIS
        Retrieves OceanStor snapshot consistency groups.

    .DESCRIPTION
        Gets snapshot consistency groups from OceanStor and optionally filters the returned groups by name.
        Returned objects use the OceanstorSnapshotConsistencyGroup class and include a default display set for common consistency group properties.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Name
        Optional snapshot consistency group name to return. When omitted, all visible snapshot consistency groups are returned.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorSnapshotConsistencyGroup

    .EXAMPLE
        PS> Get-DMSnapshotConsistencyGroup

        Returns all visible snapshot consistency groups.

    .EXAMPLE
        PS> Get-DMSnapshotConsistencyGroup -Name 'scg-production'

        Returns the snapshot consistency group named scg-production.

    .NOTES
        Filename: Get-DMSnapshotConsistencyGroup.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
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
        $script:CurrentOceanstorSession
    }
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'SNAPSHOT_CONSISTENCY_GROUP' |
        Select-DMResponseData
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
