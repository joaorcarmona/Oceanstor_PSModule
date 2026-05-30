function Get-DMvLans {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage existent vlans

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage existent vlans

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor existent configured vlans

	.EXAMPLE

		PS C:\> Get-DMvLans -webSession $session

		OR

		PS C:\> $vlans = Get-DMvLans

	.NOTES
		Filename: Get-DMvLans.ps1
		Author: Joao Carmona
		Modified date: 2022-06-07
		Version 0.1

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

    $defaultDisplaySet = "Id", "Name", "Vlan Tag Id", "Port Type", "Running Status"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "vlan" | Select-Object -ExpandProperty data
    $vlans = New-Object System.Collections.ArrayList

    foreach ($tvlan in $response) {
        $vlan = [OceanStorvLan]::new($tvlan, $session)
        [void]$vlans.Add($vlan)
    }

    $vlans | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $vlans
    return $result
}
