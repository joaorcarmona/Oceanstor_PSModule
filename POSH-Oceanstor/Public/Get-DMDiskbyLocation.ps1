function Get-DMDiskbyLocation {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks by the location

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks by location

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Location
		Mandatory parameter Location Enclosure/Slot (String), to search for a disk

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide Location by property name.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects whose location matches the supplied Location value.
	.EXAMPLE

		PS C:\> Get-DMDiskbyLocation -webSession $session -Location DAE000.24

		OR

		PS C:\> $disks = Get-DMDiskbyLocation $session -Location DAE000.24

	.NOTES
		Filename: Get-DMDiskbyLocation.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [pscustomobject]$location
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

    $response = Invoke-DMPagedRequest -WebSession $session -Resource "disk"
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
