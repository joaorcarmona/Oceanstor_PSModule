function Get-DMlunsByWWN {
    <#
	.SYNOPSIS
		To Search for lun by lun WWN

	.DESCRIPTION
		Function to search for a lun based on lun WWN

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER wwn
		Mandatory parameter [string], to set the WWN to look for.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide wwn by property name.

	.OUTPUTS
		OceanstorLunv3
		OceanstorLunv6

		Returns LUN objects whose WWN matches the supplied wwn value. The class depends on the connected OceanStor version.

	.EXAMPLE

		PS C:\> Get-DMlunsByWWN -webSession $session -wwn "6a08cf810075766e1efc050700000005"

		OR

		PS C:\> $luns = Get-DMlunsByWWN -wwn "6a08cf810075766e1efc050700000005"

	.NOTES
		Filename: Get-DMlunsByWWN.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Position = 1, Mandatory = $true)]
        [pscustomobject]$wwn
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

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun" | Select-Object -ExpandProperty data
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
        #$lun = [OceanstorLun]::new($tlun,$session)
        [void]$StorageLuns.Add($lun)
    }

    $result = $StorageLuns | Where-Object wwn -Match $wwn

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}
