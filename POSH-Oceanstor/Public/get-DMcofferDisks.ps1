function get-DMcofferDisks{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage System coffer disks

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage System coffer disks

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage System coffer disks

	.EXAMPLE

		PS C:\> get-DMcofferDisks -webSession $session

		OR

		PS C:\> $cofferDisks = get-DMcofferDisks

	.NOTES
		Filename: get-DMcofferDisks.ps1
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-Object -ExpandProperty data
    $Storagedisks = New-Object System.Collections.ArrayList

	foreach ($tdisk in $response)
	{
		$disk = [OceanStorDisks]::new($tdisk)
		$Storagedisks += $disk
	}

	$result = $Storagedisks | Where-Object cofferDisk -eq $true

	return $result
}