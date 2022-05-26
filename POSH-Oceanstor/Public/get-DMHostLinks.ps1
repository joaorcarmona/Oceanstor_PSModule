function get-DMHostLinks{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host links

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host links

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER HostId
		Host ID to Query the Host Links

	.PARAMETER InitiatorType
		Host Initiator Type (ISCSI, FC, Infiniband)

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage Host links

	.EXAMPLE

		PS C:\> get-DMHostLinks -webSession $session -HostId 1 -InitiatorType FC

		OR

		PS C:\> $disks = get-DMHostLinks -HostId 1 -InitiatorType FC

	.NOTES
		Filename: get-DMHostFCLinks.ps1
		Author: Joao Carmona
		Modified date: 2022-05-25
		Version 0.1

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$true)]
		[string]$HostId,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$true)]
		[ValidateSet("ISCSI","FC","Infiniband")]
		[string]$InitiatorType
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

	switch ($InitiatorType) {
		ISCSI {$LinkType = 222}
		FC {$LinkType = 223}
		Infiniband {$LinkType = 16499}
	}

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host_link?INITIATOR_TYPE=$LinkType&PARENTID=$HostId" | Select-Object -ExpandProperty data
    $hostLinks = New-Object System.Collections.ArrayList

	foreach ($hlinks in $response)
	{
		$hostlink = [OceanStorHostLink]::new($hlinks)
		$hostLinks += $hostlink
	}

	$result = $hostLinks

	return $result
}