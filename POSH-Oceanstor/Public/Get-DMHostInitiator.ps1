function Get-DMHostInitiator {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host Initiators

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host Initiators

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used
	.PARAMETER HostId
		Optional parameter to Query the Initiators for a specific Host Id
	.PARAMETER FreeInitiators
		Optional switch parameter to Query the Initiators that are free
	.PARAMETER InitiatorType
		Mandatory parameter to define the initiator type. Valid values are FibreChannel and ISCSI.
	.PARAMETER All
		(Default) Optional switch parameter to Query the All Initiators. If no other parameter is passed, function assume all

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanstorHostinitiatorFC
		OceanstorHostinitiatorISCSI

		Returns Fibre Channel or iSCSI host initiator objects, depending on InitiatorType.

	.EXAMPLE

		PS C:\> Get-DMHostInitiator -webSession $session -initiatorType "FibreChannel"

		OR

		PS C:\> $fcInitiators = Get-DMHostInitiator -All -initiatorType "FibreChannel"

	.EXAMPLE

		PS C:\> Get-DMHostInitiator -webSession $session -FreeInitiators -initiatorType "ISCSI"

		OR

		PS C:\> $fcInitiators = Get-DMHostInitiator -FreeInitiators -initiatorType "ISCSI"

	.EXAMPLE

		PS C:\> Get-DMHostInitiator -webSession $session -hostId 1 -initiatorType "FibreChannel"

		OR

		PS C:\> $fcInitiators = Get-DMHostInitiator -hostId 1 -initiatorType "FibreChannel"

	.NOTES
		Filename: Get-DMHostInitiator.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding(DefaultParameterSetName = "AllInitiators")]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateSet("FibreChannel", "ISCSI")]
        [string]$InitiatorType,
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
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Type", "Host Name", "Running Status", "Is Free"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    switch ($InitiatorType) {
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
        switch ($InitiatorType) {
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

Set-Alias -Name Get-DMHostInitiators -Value Get-DMHostInitiator
