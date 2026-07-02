function Get-DMdiskbyPoolName {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks configured in a Storage Pool

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks configured in a given Storage Pool Name

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER poolName
		Mandatory storage pool name used to search for configured disks.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide poolName by property name.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects whose poolName matches the supplied poolName value.

	.EXAMPLE

		PS C:\> Get-DMdiskbyPoolId -webSession $session poolName StoragePool001

		OR

		PS C:\> $disks = Get-DMdiskbyPoolId $session poolName StoragePool001

	.NOTES
		Filename: Get-DMdiskbyPoolName.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [pscustomobject]$poolName
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Location", "Health Status", "Disk Usage", "PoolName"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-DMResponseData
    $Storagedisks = New-Object System.Collections.ArrayList

    foreach ($tdisk in $response) {
        $disk = [OceanStorDisks]::new($tdisk, $session)
        [void]$Storagedisks.Add($disk)
    }

    $result = $Storagedisks | Where-Object poolName -Match $poolName

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMdisksbyPoolName -Value Get-DMdiskbyPoolName
