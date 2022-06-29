function get-DMLifs{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage existent LIFs

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage existent Logical Interfaces

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage existent LIFs

	.EXAMPLE

		PS C:\> get-DMLifs -webSession $session

		OR

		PS C:\> $lifs = get-DMLifs

	.NOTES
		Filename: get-DMLifs.ps1
		Author: Joao Carmona
		Modified date: 2022-06-08
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lif" | Select-Object -ExpandProperty data
    $lifs = New-Object System.Collections.ArrayList

	foreach ($tlif in $response)
	{
		$lif = [OceanStorLIF]::new($tlif)
		$lifs += $lif
	}

	$result = $lifs
	return $result
}