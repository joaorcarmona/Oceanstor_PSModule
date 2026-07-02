function Get-DMLif {
    <#
	.SYNOPSIS
		To Get Huawei OceanStor Storage LIFs

	.DESCRIPTION
		Function to request configured Huawei OceanStor logical interfaces.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorLIF

		Returns logical interface objects.

	.EXAMPLE

		PS C:\> Get-DMLif -webSession $session

		OR

		PS C:\> $lifs = Get-DMLif

	.NOTES
		Filename: Get-DMLif.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "LIF Name", "IPv4 Address", "Running Status", "Support Protocol"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lif" | Select-DMResponseData
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

Set-Alias -Name Get-DMLifs -Value Get-DMLif
