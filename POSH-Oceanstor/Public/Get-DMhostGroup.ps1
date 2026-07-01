function Get-DMhostGroup {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host Groups

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorHostGroup

		Returns host group objects.

	.EXAMPLE

		PS C:\> Get-DMhostGroup -webSession $session

		OR

		PS C:\> $hostGroups = Get-DMhostGroup

	.NOTES
		Filename: Get-DMhostGroup.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [string]$VstoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Name", "Is Mapped", "Host Member Number", "vStore Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'hostgroup'
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }
    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $hostgroups = New-Object System.Collections.ArrayList

    foreach ($hgroup in $response) {
        $hostgroup = [OceanStorHostGroup]::new($hgroup, $session)
        [void]$hostgroups.Add($hostgroup)
    }

    $hostgroups | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $hostgroups

    return $result
}

Set-Alias -Name Get-DMhostGroups -Value Get-DMhostGroup
