function Get-DMdisksbyPoolId {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks configured in a Storage Pool

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks configured in a given Storage Pool ID

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER poolId
		Mandatory storage pool ID used to search for configured disks.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide poolId by property name.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects whose poolId matches the supplied poolId value.

	.EXAMPLE

		PS C:\> Get-DMdisksbyPoolId -webSession $session -poolID 1

		OR

		PS C:\> $disks = Get-DMdisksbyPoolId $session -poolID 1

	.NOTES
		Filename: Get-DMdisksbyPoolId.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [pscustomobject]$poolId
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

    $result = $Storagedisks | Where-Object poolId -Match $poolID

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}
