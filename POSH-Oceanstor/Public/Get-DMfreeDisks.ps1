function Get-DMfreeDisks {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage free disks (not used)

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage free disks (not used)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage free disks (not used)

	.EXAMPLE

		PS C:\> Get-DMfreeDisks -webSession $session

		OR

		PS C:\> $freeDisks = Get-DMfreeDisks

	.NOTES
		Filename: Get-DMfreeDisks.ps1
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

    $result = $Storagedisks | Where-Object 'Disk Usage' -EQ "free"

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}
