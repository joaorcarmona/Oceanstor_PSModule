function get-DMvLans{
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

		PS C:\> get-DMvLans -webSession $session

		OR

		PS C:\> $vlans = get-DMvLans

	.NOTES
		Filename: get-DMvLans.ps1
		Author: Joao Carmona
		Modified date: 2022-06-07
		Version 0.1

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "vlan" | Select-Object -ExpandProperty data
    $vlans = New-Object System.Collections.ArrayList

	foreach ($tvlan in $response)
	{
		$vlan = [OceanStorvLan]::new($tvlan,$session)
		$vlans += $vlan
	}

	$result = $vlans
	return $result
}