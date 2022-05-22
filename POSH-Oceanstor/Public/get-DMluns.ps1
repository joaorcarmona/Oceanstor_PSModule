function get-DMluns{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Luns

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Luns

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage luns in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMluns -webSession $session

		OR

		PS C:\> $luns = get-DMluns

	.NOTES
		Filename: get-DMluns.ps1
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun" | Select-Object -ExpandProperty data
    $StorageLuns = New-Object System.Collections.ArrayList

	foreach ($tlun in $response)
	{
		$lun = [OceanstorDeviceLun]::new($tlun)
		$StorageLuns += $lun
	}

	$result = $storageLuns

	return $result
}