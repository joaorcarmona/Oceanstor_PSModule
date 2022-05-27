function get-DMFcInitiators{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage FC Initiators

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Fibre Channel Initiators

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Huawei Oceanstor Storage Fibre Channel Initiators

	.EXAMPLE

		PS C:\> get-DMFcInitiators -webSession $session

		OR

		PS C:\> $fcInitiators = get-DMFcInitiators

	.NOTES
		Filename: get-DMFcInitiators.ps1
		Author: Joao Carmona
		Modified date: 2022-05-27
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "fc_initiator" | Select-Object -ExpandProperty data
    $fcInitiators = New-Object System.Collections.ArrayList

	foreach ($initator in $response)
	{
		$fcInitiator = [oceanstorhostinitiator]::new($initator)
		$fcInitiators += $fcInitiator
	}

	$result = $fcInitiators

	return $result
}