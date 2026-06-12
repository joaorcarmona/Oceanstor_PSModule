function Get-DMvStore {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage vStores configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage vStores configured in the system

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorvStore

		Returns vStore objects.

	.EXAMPLE

		PS C:\> Get-DMvStore -webSession $session

		OR

		PS C:\> $vStores = Get-DMvStore

	.NOTES
		Filename: Get-DMvStore.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

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

    $defaultDisplaySet = "Id", "Name", "Running Status", "SAN Free Capacity Quota", "NAS Free Capacity Quota"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "vstore" | Select-Object -ExpandProperty data
    $vStores = New-Object System.Collections.ArrayList

    foreach ($tvstore in $response) {
        $vStore = [OceanStorvStore]::new($tvstore, $session)
        [void]$vStores.Add($vStore)
    }

    $vStores | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $vStores

    return $result
}
