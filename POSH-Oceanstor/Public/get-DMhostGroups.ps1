function get-DMhostGroups{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host Groups

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage Host Groups in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMhostGroups -webSession $session

		OR

		PS C:\> $hostGroups = get-DMhostGroups

	.NOTES
		Filename: get-DMhostGroups.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "hostgroup" | Select-Object -ExpandProperty data
    $hostgroups = New-Object System.Collections.ArrayList

	foreach ($hgroup in $response)
	{
		$hostgroup = [OceanStorHostGroup]::new($hgroup)
		$hostgroups += $hostgroup
	}

	$result = $hostgroups

	return $result
}
