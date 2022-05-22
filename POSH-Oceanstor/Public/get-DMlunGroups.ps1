function get-DMlunGroups{
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

		PS C:\> get-DMlunGroups -webSession $session

		OR

		PS C:\> $lunGroups = get-DMlunGroups

	.NOTES
		Filename: get-DMlunGroups.ps1
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lungroup" | Select-Object -ExpandProperty data
    $lunGroups = New-Object System.Collections.ArrayList

	foreach ($lgroup in $response)
	{
		$lunGroup = [OceanStorLunGroup]::new($lgroup)
		$lunGroups += $lunGroup
	}

	$result = $lunGroups

	return $result
}