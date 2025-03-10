function get-DMnfsFileClient{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage NFS File Clients

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage NFS File Clients

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage NFS File Clients in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMnfsFileClient -webSession $session

		OR

		PS C:\> $exports = get-DMnfsFileClient

	.NOTES
		Filename: get-DMnfsFileClient.ps1
		Author: Joao Carmona
		Modified date: 2025-03-09
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "NFS_SHARE_AUTH_CLIENT" | Select-Object -ExpandProperty data
    $exports = New-Object System.Collections.ArrayList

	foreach ($fs in $response)
	{
		$fileSystem = [OceanstorNFSclient]::new($fs)
		$exports += $fileSystem
	}

	$result = $exports

	return $result
}
