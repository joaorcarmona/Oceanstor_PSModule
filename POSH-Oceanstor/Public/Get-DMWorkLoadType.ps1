function Get-DMWorkLoadType {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage workload Type configured (only works for v6)

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage workload Type configured (only works for v6)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorWorkload

		Returns workload type objects. This command only works for V6 arrays.

	.EXAMPLE

		PS C:\> Get-DMWorkLoadType -webSession $session

		OR

		PS C:\> $workloads = Get-DMWorkLoadType

	.NOTES
		Filename: Get-DMWorkLoadType.ps1

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

    $defaultDisplaySet = "Id", "Name", "Workload Type", "Block Size", "Compression Enabled"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "workload_type?isDetailInfo=true" | Select-DMResponseData
    $workloads = New-Object System.Collections.ArrayList

    foreach ($tworkload in $response) {
        $workload = [OceanStorWorkload]::new($tworkload, $session)
        [void]$workloads.Add($workload)
    }

    $workloads | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $workloads
    return $result
}

Set-Alias -Name Get-DMWorkLoadTypes -Value Get-DMWorkLoadType
