function get-DMFileSystem{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage File Systems

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage File Systems

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage File Systems in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMFileSystem -webSession $session

		OR

		PS C:\> $FileSystems = get-DMFileSystem

	.NOTES
		Filename: get-DMFileSystem.ps1
		Author: Joao Carmona
		Modified date: 2022-05-24
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "filesystem" | Select-Object -ExpandProperty data
    $FileSystems = New-Object System.Collections.ArrayList

	foreach ($fs in $response)
	{
		$fileSystem = [OceanstorFileSystem]::new($fs)
		$FileSystems += $fileSystem
	}

	$result = $FileSystems

	return $result
}