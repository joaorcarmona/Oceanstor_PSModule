function Get-DMWorkLoadTypesbyFilter {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage workload Type configured (only works for v6), by inputing a filter

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage workload Type configured

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER filter
		Mandatory parameter [string], to be used as filter in the query. Needs to be a valid property name for the Workload Object.
    .PARAMETER filter
        Mandatory parameter [string], to be used as keyword to search for Workload. No need explicit wildcard (*), because it's implicit

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage workload Type configured (only works for v6)

	.EXAMPLE

		PS C:\> Get-DMWorkLoadTypesbyFilter -webSession $session -Filter "Compression Enabled" -keyword "enabled"

		OR

		PS C:\> $workloads = Get-DMWorkLoadTypesbyFilter -webSession $session -Filter "Compression Enabled" -keyword "enabled"

	.NOTES
		Filename: Get-DMWorkLoadTypesbyFilter.ps1
		Author: Joao Carmona
		Modified date: 2022-06-29
		Version 0.1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Position = 1, Mandatory = $true)]
        [pscustomobject]$filter,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Position = 2, Mandatory = $true)]
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

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "workload_type?isDetailInfo=true" | Select-Object -ExpandProperty data
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
