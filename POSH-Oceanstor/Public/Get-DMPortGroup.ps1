<#
.SYNOPSIS
    Retrieves OceanStor port groups.

.DESCRIPTION
    Gets port groups from OceanStor, optionally filtered by name and optionally scoped to a vStore.
    Returned objects use the OceanstorPortGroup class and include a default display set for common port group properties.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Optional port group name to return. When omitted, all visible port groups are returned.

.PARAMETER VstoreId
    Optional vStore ID used to scope the port group query.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorPortGroup

.EXAMPLE
    PS> Get-DMPortGroup -Name 'fc-front-end'

    Returns the port group named fc-front-end.

.EXAMPLE
    PS> Get-DMPortGroup -VstoreId '1'

    Returns port groups scoped to vStore ID 1.

.NOTES
    Filename: Get-DMPortGroup.ps1
#>
function Get-DMPortGroup {
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
        $script:CurrentOceanstorSession
    }
    $resource = 'portgroup'
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource |
        Select-DMResponseData
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
