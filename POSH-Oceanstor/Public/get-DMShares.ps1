function get-DMShares{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Shares

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Shares

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER shareType
		Mamdatory paramter to define the Share Type to Query ("NFS","CIFS")

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage Shares

	.EXAMPLE

		PS C:\> get-DMShares -webSession $session -shareType CIFS

		OR

		PS C:\> $shares = get-DMShares -shareType NFS

	.NOTES
		Filename: get-DMShares.ps1
		Author: Joao Carmona
		Modified date: 2022-05-28
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(Position=1,Mandatory=$true)]
        [ValidateSet("CIFS","NFS")]
        [string]$shareType
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

	switch ($shareType)
	{
		CIFS {$resourceQuery = "CIFSHARE"}
		NFS {$resourceQuery = "NFSHARE"}
	}

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resourceQuery | Select-Object -ExpandProperty data
    $shares = New-Object System.Collections.ArrayList

	foreach ($tshare in $response)
	{
		switch ($shareType)
		{
			CIFS {$share = [OceanStorCIFSShare]::new($tshare)}
			NFS {$share = [OceanStorNFSShare]::new($tshare)}
		}

		$shares += $share
	}

	$result = $shares
	return $result
}