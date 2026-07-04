function Get-DMvLan {
    <#
	.SYNOPSIS
		To Get Huawei OceanStor Storage VLANs

	.DESCRIPTION
		Function to request configured Huawei OceanStor VLANs.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorvLan

		Returns VLAN objects.

	.EXAMPLE

		PS C:\> Get-DMvLan -webSession $session

		OR

		PS C:\> $vlans = Get-DMvLan

	.NOTES
		Filename: Get-DMvLan.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Vlan Tag Id", "Port Type", "Running Status"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "vlan" | Select-DMResponseData
    $vlans = New-Object System.Collections.ArrayList

    foreach ($tvlan in $response) {
        $vlan = [OceanStorvLan]::new($tvlan, $session)
        [void]$vlans.Add($vlan)
    }

    $vlans | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $vlans
    return $result
}

Set-Alias -Name Get-DMvLans -Value Get-DMvLan
