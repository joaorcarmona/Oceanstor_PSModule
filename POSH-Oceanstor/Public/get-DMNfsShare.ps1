function get-DMNFSShare{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage NFS Shares

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage NFS Shares

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage  NFS Shares

	.EXAMPLE

		PS C:\> get-DMNFSShare -webSession $session

		OR

		PS C:\> $disks = get-DMNFSShare

	.NOTES
		Filename: get-DMNFSShare.ps1
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "NFSHARE" | Select-Object -ExpandProperty data
    $shares = New-Object System.Collections.ArrayList

	foreach ($nshare in $response)
	{
		$share = [OceanStorNFSShare]::new($nshare)
		$shares += $share
	}

	$result = $share
	return $result
}