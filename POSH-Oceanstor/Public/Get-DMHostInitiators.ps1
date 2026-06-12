function Get-DMHostInitiators {
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
	.PARAMETER initatorType
		Mandatory parameter to define the initiator type. Valid values are FibreChannel and ISCSI.
		The correctly spelled -InitiatorType name is available as an alias.
	.PARAMETER All
		(Default) Optional switch parameter to Query the All Initiators. If no other parameter is passed, function assume all

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanstorHostinitiatorFC
		OceanstorHostinitiatorISCSI

		Returns Fibre Channel or iSCSI host initiator objects, depending on InitatorType.

	.EXAMPLE

		PS C:\> Get-DMHostInitiators -webSession $session -initiatorType "FibreChannel"

		OR

		PS C:\> $fcInitiators = Get-DMHostInitiators -All -initiatorType "FibreChannel"

	.EXAMPLE

		PS C:\> Get-DMHostInitiators -webSession $session -FreeInitiators -initiatorType "ISCSI"

		OR

		PS C:\> $fcInitiators = Get-DMHostInitiators -FreeInitiators -initiatorType "ISCSI"

	.EXAMPLE

		PS C:\> Get-DMHostInitiators -webSession $session -hostId 1 -initiatorType "FibreChannel"

		OR

		PS C:\> $fcInitiators = Get-DMHostInitiators -hostId 1 -initiatorType "FibreChannel"

	.NOTES
		Filename: Get-DMHostInitiators.ps1
		Author: Joao Carmona
		Modified date: 2022-05-27
		Version 0.2

	.LINK
	#>
    [Cmdletbinding(DefaultParameterSetName = "AllInitiators")]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateSet("FibreChannel", "ISCSI")]
        [Alias("InitiatorType")]
        [string]$initatorType,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 1, Mandatory = $false, ParameterSetName = "HostInitiators")]
        [string]$hostId,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 2, Mandatory = $false, ParameterSetName = "FreeInitiators")]
        [switch]$FreeInitiators = $false,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 2, Mandatory = $false, ParameterSetName = "AllInitiators")]
        [switch]$All = $false
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Type", "Host Name", "Running Status", "Is Free"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    switch ($initatorType) {
        FibreChannel {
            $resourceQuery = "fc_initiator"
        }
        ISCSI {
            $resourceQuery = "iscsi_initiator"
        }
    }

    switch ($PSCmdlet.ParameterSetName) {
        HostInitiators {
            $resource = $resourceQuery + "?PARENTID=" + $hostId
        }
        FreeInitiators {
            $resource = $resourceQuery + "?ISFREE=true"
        }
        default {
            $resource = "$resourceQuery"
        }
    }

    $queryResult = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource
    $response = @()

    if ($null -ne $queryResult -and $null -ne $queryResult.PSObject.Properties['data']) {
        $response = @($queryResult.data)
    }

    $HostInitiators = New-Object System.Collections.ArrayList

    foreach ($initator in $response) {
        switch ($initatorType) {
            FibreChannel {
                $HostInitiator = [OceanstorHostinitiatorFC]::new($initator, $session)
            }
            ISCSI {
                $HostInitiator = [OceanstorHostinitiatorISCSI]::new($initator, $session)
            }
        }

        [void]$HostInitiators.Add($HostInitiator)
    }

    $HostInitiators | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $HostInitiators

    return $result
}
