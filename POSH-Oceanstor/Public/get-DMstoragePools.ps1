function get-DMstoragePools{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Pools Configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Pools Configured in the system

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage pools in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMstoragePools -webSession $session

		OR

		PS C:\> $StoragePools = get-DMstoragePools

	.NOTES
		Filename: get-DMstoragePools.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

	$defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "DataSpace"

	$displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
		'DefaultDisplayPropertySet',
		[string[]]$defaultDisplaySet
	)

	$standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "storagepool" | Select-Object -ExpandProperty data
    $storagePools = New-Object System.Collections.ArrayList

	foreach ($spool in $response)
	{
		$storagepool = [OceanStorStoragePool]::new($spool, $session)
		[void]$storagePools.Add($storagepool)
	}

	$storagePools | ForEach-Object {
		$_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
	}

	$result = $storagePools

	return $result
}
