<#
.SYNOPSIS
    Retrieves OceanStor protection groups.

.DESCRIPTION
    Gets protection groups from OceanStor through the API v2 protection group interface.
    Results can be filtered by name after retrieval and are returned as OceanstorProtectionGroup objects.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Optional protection group name to return. When omitted, all visible protection groups are returned.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorProtectionGroup

.EXAMPLE
    PS> Get-DMProtectionGroup -Name 'pg-production'

    Returns the protection group named pg-production.

.EXAMPLE
    PS> Get-DMProtectionGroup

    Returns all visible protection groups.

.NOTES
    Filename: Get-DMProtectionGroup.ps1
#>
function Get-DMProtectionGroup {
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
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'protectgroup' -ApiV2 |
        Select-DMResponseData
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
