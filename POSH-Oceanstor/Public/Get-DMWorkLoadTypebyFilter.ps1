function Get-DMWorkLoadTypebyFilter {
    <#
	.SYNOPSIS
		To Get Huawei OceanStor workload types by filter. This command only works for V6 arrays.

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage workload Type configured

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER filter
		Mandatory property name to filter against. The value must be a valid workload object property.

    .PARAMETER keyword
        Mandatory keyword used to search for workload types. Wildcards are not required because the match is implicit.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide filter values by property name.

	.OUTPUTS
		OceanStorWorkload

		Returns workload type objects matching the requested property filter and keyword. This command only works for V6 arrays.

	.EXAMPLE

		PS C:\> Get-DMWorkLoadTypebyFilter -webSession $session -Filter "Compression Enabled" -keyword "enabled"

		OR

		PS C:\> $workloads = Get-DMWorkLoadTypebyFilter -webSession $session -Filter "Compression Enabled" -keyword "enabled"

	.NOTES
		Filename: Get-DMWorkLoadTypebyFilter.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [pscustomobject]$filter,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 2, Mandatory = $true)]
        [pscustomobject]$keyword
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

    $result = $workloads | Where-Object $filter -Match $keyword

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMWorkLoadTypesbyFilter -Value Get-DMWorkLoadTypebyFilter
