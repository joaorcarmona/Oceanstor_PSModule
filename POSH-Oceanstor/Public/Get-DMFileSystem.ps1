function Get-DMFileSystem {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage File Systems

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage File Systems

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage File Systems in the system. Return an Array object.

	.EXAMPLE

		PS C:\> Get-DMFileSystem -webSession $session

		OR

		PS C:\> $FileSystems = Get-DMFileSystem

	.NOTES
		Filename: Get-DMFileSystem.ps1
		Author: Joao Carmona
		Modified date: 2025-03-09
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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Capacity (GB)"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "filesystem" | Select-Object -ExpandProperty data
    $FileSystems = New-Object System.Collections.ArrayList

    foreach ($fs in $response) {
        $fileSystem = [OceanstorFileSystem]::new($fs, $session)
        [void]$FileSystems.Add($fileSystem)
    }

    $FileSystems | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $FileSystems

    return $result
}
