function Get-DMPortGroup {
    <#
    .SYNOPSIS
        Retrieves Huawei OceanStor port groups.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 1)]
        [string]$Name,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $resource = 'portgroup'
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource |
        Select-Object -ExpandProperty data
    $defaultDisplaySet = 'Id', 'Name', 'Port Type', 'Port Count', 'Is Mapped', 'vStore Name'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $groups = [System.Collections.ArrayList]::new()

    foreach ($groupData in @($response)) {
        $group = [OceanstorPortGroup]::new($groupData, $session)
        if (-not $Name -or $group.Name -eq $Name) {
            $group | Add-Member MemberSet PSStandardMembers $standardMembers -Force
            [void]$groups.Add($group)
        }
    }

    return $groups
}
