function Get-DMSystem {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor DeviceManager basic properties

	.DESCRIPTION
		Requests basic Huawei OceanStor DeviceManager properties.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorSystem

		Returns the OceanStor system object.

	.EXAMPLE

		PS C:\> Get-DMSystem -webSession $session

		OR

		PS C:\> $StorageDM = Get-DMSystem

	.NOTES
		Filename: OceanstorPSModulePSBase.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "system/" | Select-DMResponseData
    $response = $response -replace "[@{}]"
    [array]$systemArray = $response.Split(";")

    $defaultDisplaySet = "sn", "version", "Health Status", "Running Status", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $result = [OceanStorSystem]::new($systemArray, $session)
    $result | Add-Member MemberSet PSStandardMembers $standardMembers -Force

    return $result
}
