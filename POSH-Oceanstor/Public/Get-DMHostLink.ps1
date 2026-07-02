function Get-DMHostLink {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host links

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host links

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER HostId
		Host ID to Query the Host Links

	.PARAMETER InitiatorType
		Host Initiator Type (ISCSI, FC, Infiniband)

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide HostId or InitiatorType by property name.

	.OUTPUTS
		OceanStorHostLink

		Returns host link objects for the requested host and initiator type.

	.EXAMPLE

		PS C:\> Get-DMHostLink -webSession $session -HostId 1 -InitiatorType FC

		OR

		PS C:\> $disks = Get-DMHostLink -HostId 1 -InitiatorType FC

	.NOTES
		Filename: Get-DMHostFCLinks.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $true)]
        [string]$HostId,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $true)]
        [ValidateSet("ISCSI", "FC", "Infiniband")]
        [string]$InitiatorType
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Host Name", "Initiator Type", "Target Type", "Running Status"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    switch ($InitiatorType) {
        ISCSI {
            $LinkType = 222
        }
        FC {
            $LinkType = 223
        }
        Infiniband {
            $LinkType = 16499
        }
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host_link?INITIATOR_TYPE=$LinkType&PARENTID=$HostId" | Select-DMResponseData
    $hostLinks = New-Object System.Collections.ArrayList

    foreach ($hlinks in $response) {
        $hostlink = [OceanStorHostLink]::new($hlinks, $session)
        [void]$hostLinks.Add($hostlink)
    }

    $hostLinks | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $hostLinks

    return $result
}

Set-Alias -Name Get-DMHostLinks -Value Get-DMHostLink
