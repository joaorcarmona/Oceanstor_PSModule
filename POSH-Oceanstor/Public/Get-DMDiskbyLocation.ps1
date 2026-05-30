function Get-DMDiskbyLocation {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks by the location

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks by location

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER Location
		Mandatory parameter Location Enclosure/Slot (String), to search for a disk

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage disks object
	.EXAMPLE

		PS C:\> Get-DMDiskbyLocation -webSession $session -Location DAE000.24

		OR

		PS C:\> $disks = Get-DMDiskbyLocation $session -Location DAE000.24

	.NOTES
		Filename: Get-DMDiskbyLocation.ps1
		Author: Joao Carmona
		Modified date: 2022-05-24
		Version 0.1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [pscustomobject]$location
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

    $result = $Storagedisks | Where-Object location -Match $location

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}
