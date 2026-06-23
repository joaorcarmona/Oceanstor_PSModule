function Get-DMlunGroup {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Lun Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Lun Groups

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorLunGroup

		Returns LUN group objects.

	.EXAMPLE

		PS C:\> Get-DMlunGroup -webSession $session

		OR

		PS C:\> $lunGroups = Get-DMlunGroup

	.EXAMPLE

		PS C:\> $lunGroup = (Get-DMlunGroup -WebSession $session)[0]
		PS C:\> $memberLuns = $lunGroup.GetLuns()

	.NOTES
		Filename: Get-DMlunGroup.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Name", "LunGroup Capacity", "Is Mapped", "Luns Members number"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lungroup" | Select-Object -ExpandProperty data
    $lunGroups = New-Object System.Collections.ArrayList

    foreach ($lgroup in $response) {
        $lunGroup = [OceanStorLunGroup]::new($lgroup, $session)
        [void]$lunGroups.Add($lunGroup)
    }

    $lunGroups | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $lunGroups

    return $result
}

Set-Alias -Name Get-DMlunGroups -Value Get-DMlunGroup
