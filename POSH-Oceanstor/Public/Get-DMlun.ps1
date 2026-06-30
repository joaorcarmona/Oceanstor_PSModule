function Get-DMlun {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Luns

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Luns

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanstorLunv3
		OceanstorLunv6

		Returns LUN objects. The class depends on the connected OceanStor version.

	.EXAMPLE

		PS C:\> Get-DMlun -webSession $session

		OR

		PS C:\> $luns = Get-DMlun

	.NOTES
		Filename: Get-DMlun.ps1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)


    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'lun'
    $StorageLuns = New-Object System.Collections.ArrayList

    $StorageVersion = $session.version.Substring(0, 2)

    if ($storageVersion -eq "V6") {
        $LunObjectClass = "OceanstorLunv6"
    }
    else {
        $LunObjectClass = "OceanstorLunv3"
    }

    foreach ($tlun in $response) {
        $lun = New-Object -TypeName $LunObjectClass -ArgumentList @($tlun, $session)
        [void]$StorageLuns.Add($lun)
    }

    $StorageLuns | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $storageLuns

    return $result
}

Set-Alias -Name Get-DMluns -Value Get-DMlun
