function Get-DMcofferDisk {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage System coffer disks

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage System coffer disks

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorDisks

		Returns disk objects where cofferDisk is true.

	.EXAMPLE

		PS C:\> Get-DMcofferDisk -webSession $session

		OR

		PS C:\> $cofferDisks = Get-DMcofferDisk

	.NOTES
		Filename: Get-DMcofferDisk.ps1

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

    $result = $Storagedisks | Where-Object cofferDisk -EQ $true

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMcofferDisks -Value Get-DMcofferDisk
