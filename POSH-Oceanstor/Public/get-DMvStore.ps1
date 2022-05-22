function get-DMvStore{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage vStores configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage vStores configured in the system

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage vStores configured in the system. Array type return

	.EXAMPLE

		PS C:\> get-DMvStore -webSession $session

		OR

		PS C:\> $vStores = get-DMvStore

	.NOTES
		Filename: get-DMvStore.ps1
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "vstore" | Select-Object -ExpandProperty data
    $vStores = New-Object System.Collections.ArrayList

	foreach ($tvstore in $response)
	{
		$vStore = [OceanStorvStore]::new($tvstore)
		$vStores += $vStore
	}

	$result = $vStores

	return $result
}