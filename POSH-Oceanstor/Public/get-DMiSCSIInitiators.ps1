function get-DMiSCSIInitiators{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage iSCSI Initiators

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage iSCSI Initiators

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER HostId
		Optional parameter to Query the Initiators for a specific Host Id
	.PARAMETER FreeInitiators
		Optional switch parameter to Query the Initiators that are free
	.PARAMETER All
		(Default) Optional switch parameter to Query the All Initiators. If no other parameter is passed, function assume all

	.INPUTS

	.OUTPUTS
		returns the Huawei Huawei Oceanstor Storage Fibre Channel Initiators

	.EXAMPLE

		PS C:\> get-DMiSCSIInitiators -webSession $session

		OR

		PS C:\> $fcInitiators = get-DMiSCSIInitiators -All

	.EXAMPLE

		PS C:\> get-DMiSCSIInitiators -webSession $session -FreeInitiators

		OR

		PS C:\> $fcInitiators = get-DMiSCSIInitiators -FreeInitiators

	.EXAMPLE

		PS C:\> get-DMiSCSIInitiators -webSession $session -hostId 1

		OR

		PS C:\> $fcInitiators = get-DMiSCSIInitiators -hostId 1

	.NOTES
		Filename: get-DMiSCSIInitiators.ps1
		Author: Joao Carmona
		Modified date: 2022-05-27
		Version 0.1

	.LINK
	#>
	[Cmdletbinding(DefaultParameterSetName = "AllInitiators")]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
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

	switch ($PSCmdlet.ParameterSetName)
	{
		HostInitiators {$resource = "iscsi_initiator?PARENTID=" + $hostId}
		FreeInitiators {$resource = "iscsi_initiator?ISFREE=true"}
		default {$resource = "iscsi_initiator"}
	}

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-Object -ExpandProperty data
	write-Host $response
    $fcInitiators = New-Object System.Collections.ArrayList

	foreach ($initator in $response)
	{
		$fcInitiator = [OceanstorHostinitiatorISCSI]::new($initator)
		$fcInitiators += $fcInitiator
	}

	$result = $fcInitiators

	return $result
}