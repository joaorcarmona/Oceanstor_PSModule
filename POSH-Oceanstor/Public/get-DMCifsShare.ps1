function get-DMCifsShare{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage CIFS Shares

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage  CIFS Shares

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage  CIFS Shares

	.EXAMPLE

		PS C:\> get-DMCifsShare -webSession $session

		OR

		PS C:\> $disks = get-DMCifsShare

	.NOTES
		Filename: get-DMCifsShare.ps1
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "CIFSHARE" | Select-Object -ExpandProperty data
    $shares = New-Object System.Collections.ArrayList

	foreach ($cshare in $response)
	{
		$share = [OceanStorCIFSShare]::new($cshare)
		$shares += $share
	}

	$result = $share
	return $result
}