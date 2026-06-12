function Get-DMdisksbyPoolName {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks configured in a Storage Pool

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks configured in a given Storage Pool Name

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER poolName
		Mandatory storage pool name used to search for configured disks.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide poolName by property name.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects whose poolName matches the supplied poolName value.

	.EXAMPLE

		PS C:\> Get-DMdisksbyPoolId -webSession $session poolName StoragePool001

		OR

		PS C:\> $disks = Get-DMdisksbyPoolId $session poolName StoragePool001

	.NOTES
		Filename: Get-DMdisksbyPoolName.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [pscustomobject]$poolName
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Location", "Health Status", "Disk Usage", "PoolName"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-Object -ExpandProperty data
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
