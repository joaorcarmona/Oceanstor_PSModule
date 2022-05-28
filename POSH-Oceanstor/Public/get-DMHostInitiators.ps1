function get-DMHostInitiators{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host Initiators

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host Initiators

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER HostId
		Optional parameter to Query the Initiators for a specific Host Id
	.PARAMETER FreeInitiators
		Optional switch parameter to Query the Initiators that are free
	.PARAMETER initiatorType
		Mandator paramater to define the initiatorType (FibreChannel|ISCSI).
	.PARAMETER All
		(Default) Optional switch parameter to Query the All Initiators. If no other parameter is passed, function assume all

	.INPUTS

	.OUTPUTS
		returns the Huawei Huawei Oceanstor Storage Host Initiators

	.EXAMPLE

		PS C:\> get-DMHostInitiators -webSession $session -initiatorType "FibreChannel"

		OR

		PS C:\> $fcInitiators = get-DMHostInitiators -All -initiatorType "FibreChannel"

	.EXAMPLE

		PS C:\> get-DMHostInitiators -webSession $session -FreeInitiators -initiatorType "ISCSI"

		OR

		PS C:\> $fcInitiators = get-DMHostInitiators -FreeInitiators -initiatorType "ISCSI"

	.EXAMPLE

		PS C:\> get-DMHostInitiators -webSession $session -hostId 1 -initiatorType "FibreChannel"

		OR

		PS C:\> $fcInitiators = get-DMHostInitiators -hostId 1 -initiatorType "FibreChannel"

	.NOTES
		Filename: get-DMHostInitiators.ps1
		Author: Joao Carmona
		Modified date: 2022-05-27
		Version 0.2

	.LINK
	#>
	[Cmdletbinding(DefaultParameterSetName = "AllInitiators")]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(Position=1,Mandatory=$true)]
        [ValidateSet("FibreChannel","ISCSI")]
        [string]$initatorType,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,Position=1,Mandatory=$false,ParameterSetName="HostInitiators")]
        [string]$hostId,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,Position=2,Mandatory=$false,ParameterSetName="FreeInitiators")]
        [switch]$FreeInitiators = $false,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,Position=2,Mandatory=$false,ParameterSetName="AllInitiators")]
        [switch]$All = $false
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

	switch ($initatorType)
	{
		FibreChannel {$resourceQuery = "fc_initiator"}
		ISCSI {$resourceQuery = "iscsi_initiator"}
	}

	switch ($PSCmdlet.ParameterSetName)
	{
		HostInitiators {$resource = $resourceQuery + "?PARENTID=" + $hostId}
		FreeInitiators {$resource = $resourceQuery + "?ISFREE=true"}
		default {$resource = "$resourceQuery"}
	}

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-Object -ExpandProperty data
    $HostInitiators = New-Object System.Collections.ArrayList

	foreach ($initator in $response)
	{
		switch ($initatorType)
		{
			FibreChannel {$HostInitiator = [OceanstorHostinitiatorFC]::new($initator)}
			ISCSI {$HostInitiator = [OceanstorHostinitiatorISCSI]::new($initator)}
		}

		$HostInitiators += $HostInitiator
	}

	$result = $HostInitiators

	return $result
}