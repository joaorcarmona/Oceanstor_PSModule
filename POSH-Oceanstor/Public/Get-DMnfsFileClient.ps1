function Get-DMnfsFileClient {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage NFS File Clients

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage NFS File Clients

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanstorNFSclient

		Returns NFS share authorization client objects.

	.EXAMPLE

		PS C:\> Get-DMnfsFileClient -webSession $session

		OR

		PS C:\> $exports = Get-DMnfsFileClient

	.NOTES
		Filename: Get-DMnfsFileClient.ps1
		Author: Joao Carmona
		Modified date: 2025-03-09
		Version 0.1

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

    $defaultDisplaySet = "Id", "Name", "NFS Share Name", "Access Permission", "WriteMode"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "NFS_SHARE_AUTH_CLIENT" | Select-Object -ExpandProperty data
    $exports = New-Object System.Collections.ArrayList

    foreach ($fs in $response) {
        $fileSystem = [OceanstorNFSclient]::new($fs, $session)
        [void]$exports.Add($fileSystem)
    }

    $exports | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $exports

    return $result
}
