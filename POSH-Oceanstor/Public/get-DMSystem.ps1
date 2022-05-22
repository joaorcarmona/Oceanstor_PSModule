function get-DMSystem{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor DeviceManager basic properties

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage DeviceManager basic proterties

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor DeviceManager basic properties

	.EXAMPLE

		PS C:\> get-DMSystem -webSession $session

		OR

		PS C:\> $StorageDM = get-DMSystem

	.NOTES
		Filename: OceanstorPSModulePSBase.ps1
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "system/" | Select-Object -ExpandProperty data
    $response = $response -replace "[@{}]"
    [array]$systemArray = $response.Split(";")

    $result = [OceanStorSystem]::new($systemArray)

	return $result
}