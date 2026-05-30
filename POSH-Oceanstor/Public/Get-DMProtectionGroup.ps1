function Get-DMProtectionGroup {
    <#
    .SYNOPSIS
        Retrieves Huawei OceanStor protection groups.
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
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'protectgroup' -ApiV2 |
        Select-Object -ExpandProperty data
    $defaultDisplaySet = 'Id', 'Name', 'Lun Group Name', 'Lun Count', 'Snapshot Group Count', 'vStore Name'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $groups = [System.Collections.ArrayList]::new()

    foreach ($groupData in @($response)) {
        $group = [OceanstorProtectionGroup]::new($groupData, $session)
        if (-not $Name -or $group.Name -eq $Name) {
            $group | Add-Member MemberSet PSStandardMembers $standardMembers -Force
            [void]$groups.Add($group)
        }
    }

    return $groups
}
