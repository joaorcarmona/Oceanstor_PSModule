function get-DMfreeDisks{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage free disks (not used)

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage free disks (not used)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage free disks (not used)

	.EXAMPLE

		PS C:\> get-DMfreeDisks -webSession $session

		OR

		PS C:\> $freeDisks = get-DMfreeDisks

	.NOTES
		Filename: get-DMfreeDisks.ps1
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

	$result = $Storagedisks | Where-Object logicType -eq "free"

	return $result
}