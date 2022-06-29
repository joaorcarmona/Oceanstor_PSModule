function get-DMWorkLoadTypesbyFilter{
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

		PS C:\> get-DMWorkLoadTypesbyFilter -webSession $session -Filter "Compression Enabled" -keyword "enabled"

		OR

		PS C:\> $workloads = get-DMWorkLoadTypesbyFilter -webSession $session -Filter "Compression Enabled" -keyword "enabled"

	.NOTES
		Filename: get-DMWorkLoadTypesbyFilter.ps1
		Author: Joao Carmona
		Modified date: 2022-06-29
		Version 0.1

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$true)]
			[pscustomobject]$filter,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$true)]
			[pscustomobject]$keyword
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }
    #host_link?INITIATOR_TYPE=$LinkType&PARENTID=$HostId
    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "workload_type?isDetailInfo=true" | Select-Object -ExpandProperty data
    $workloads = New-Object System.Collections.ArrayList

	foreach ($tworkload in $response)
	{
		$workload = [OceanStorWorkload]::new($tworkload)
		$workloads += $workload
	}

	$result = $workloads | Where-Object $filter -Match $keyword
	return $result
}