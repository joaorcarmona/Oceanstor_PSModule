function Get-DMlunGroups {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Lun Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Lun Groups

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage Lun Groups in the system. Return an Array object.

	.EXAMPLE

		PS C:\> Get-DMlunGroups -webSession $session

		OR

		PS C:\> $lunGroups = Get-DMlunGroups

	.EXAMPLE

		PS C:\> $lunGroup = (Get-DMlunGroups -WebSession $session)[0]
		PS C:\> $memberLuns = $lunGroup.GetLuns()

	.NOTES
		Filename: Get-DMlunGroups.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

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
