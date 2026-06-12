function Get-DMLifs {
    <#
	.SYNOPSIS
		To Get Huawei OceanStor Storage LIFs

	.DESCRIPTION
		Function to request configured Huawei OceanStor logical interfaces.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorLIF

		Returns logical interface objects.

	.EXAMPLE

		PS C:\> Get-DMLifs -webSession $session

		OR

		PS C:\> $lifs = Get-DMLifs

	.NOTES
		Filename: Get-DMLifs.ps1
		Author: Joao Carmona
		Modified date: 2022-06-08
		Version 0.1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "LIF Name", "IPv4 Address", "Running Status", "Support Protocol"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lif" | Select-Object -ExpandProperty data
    $lifs = New-Object System.Collections.ArrayList

    foreach ($tlif in $response) {
        $lif = [OceanStorLIF]::new($tlif, $session)
        [void]$lifs.Add($lif)
    }

    $lifs | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $lifs
    return $result
}
