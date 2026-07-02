function Get-DMstoragePool {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Pools Configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Pools Configured in the system

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorStoragePool

		Returns storage pool objects.

	.EXAMPLE

		PS C:\> Get-DMstoragePool -webSession $session

		OR

		PS C:\> $StoragePools = Get-DMstoragePool

	.NOTES
		Filename: Get-DMstoragePool.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "DataSpace"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "storagepool" | Select-DMResponseData
    $storagePools = New-Object System.Collections.ArrayList

    foreach ($spool in $response) {
        $storagepool = [OceanStorStoragePool]::new($spool, $session)
        [void]$storagePools.Add($storagepool)
    }

    $storagePools | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $storagePools

    return $result
}

Set-Alias -Name Get-DMstoragePools -Value Get-DMstoragePool
