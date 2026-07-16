function Get-DMWorkLoadTypebyFilter {
    <#
	.SYNOPSIS
		To Get Huawei OceanStor workload types by filter. This command only works for V6 arrays.

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage workload Type configured

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER filter
		Mandatory property name to filter against. The value must be a valid workload object property.

    .PARAMETER keyword
        Mandatory keyword used to search for workload types. Wildcards are not required because the match is implicit.

    .PARAMETER Name
        Wrapper for -filter/-keyword targeting the Name property. Requests a server-side
        filter=NAME:: hint (the workload_type endpoint documents NAME as a supported filter
        field) and always re-verifies the match client-side.

    .PARAMETER CompressionEnabled
        Wrapper for -filter/-keyword targeting the Compression Enabled property. Attempts a
        server-side filter=ENABLECOMPRESS:: hint, but this field is NOT confirmed as a
        supported workload_type filter parameter in the REST reference (only NAME is
        documented) — the result is always re-verified client-side regardless.

    .PARAMETER DedupeEnabled
        Wrapper for -filter/-keyword targeting the Deduplication Enabled property. Attempts a
        server-side filter=ENABLEDEDUP:: hint, but this field is NOT confirmed as a supported
        workload_type filter parameter in the REST reference (only NAME is documented) — the
        result is always re-verified client-side regardless.

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

		OR

		PS C:\> Get-DMWorkLoadTypebyFilter -webSession $session -Name "db-workload"

		OR

		PS C:\> Get-DMWorkLoadTypebyFilter -webSession $session -CompressionEnabled $true

	.NOTES
		Filename: Get-DMWorkLoadTypebyFilter.ps1

	.LINK
	#>
    [Cmdletbinding(DefaultParameterSetName = 'ByFilter')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ByFilter', ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [pscustomobject]$filter,
        [Parameter(ParameterSetName = 'ByFilter', ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [pscustomobject]$keyword,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByCompressionEnabled', Mandatory = $true)]
        [bool]$CompressionEnabled,

        [Parameter(ParameterSetName = 'ByDedupeEnabled', Mandatory = $true)]
        [bool]$DedupeEnabled
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Workload Type", "Block Size", "Compression Enabled"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = "workload_type?isDetailInfo=true"

    switch ($PSCmdlet.ParameterSetName) {
        'ByName' {
            # workload_type documents NAME as a supported filter field.
            $resource += "&filter=NAME::$([uri]::EscapeDataString($Name))"
        }
        'ByCompressionEnabled' {
            $apiValue = if ($CompressionEnabled) { 'true' } else { 'false' }
            # ENABLECOMPRESS is the raw REST field backing "Compression Enabled"; the doc
            # only confirms NAME as a supported workload_type filter field, so this
            # server-side hint is UNCONFIRMED. Re-verified client-side below regardless.
            $resource += "&filter=ENABLECOMPRESS::$apiValue"
        }
        'ByDedupeEnabled' {
            $apiValue = if ($DedupeEnabled) { 'true' } else { 'false' }
            # ENABLEDEDUP is the raw REST field backing "Deduplication Enabled"; the doc
            # only confirms NAME as a supported workload_type filter field, so this
            # server-side hint is UNCONFIRMED. Re-verified client-side below regardless.
            $resource += "&filter=ENABLEDEDUP::$apiValue"
        }
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $workloads = New-Object System.Collections.ArrayList

    foreach ($tworkload in $response) {
        $workload = [OceanStorWorkload]::new($tworkload, $session)
        [void]$workloads.Add($workload)
    }

    $result = switch ($PSCmdlet.ParameterSetName) {
        'ByName' {
            $workloads | Where-Object Name -EQ $Name
        }
        'ByCompressionEnabled' {
            $expected = if ($CompressionEnabled) { 'enabled' } else { 'disabled' }
            $workloads | Where-Object 'Compression Enabled' -EQ $expected
        }
        'ByDedupeEnabled' {
            $expected = if ($DedupeEnabled) { 'enabled' } else { 'disabled' }
            $workloads | Where-Object 'Deduplication Enabled' -EQ $expected
        }
        default {
            $workloads | Where-Object $filter -Match $keyword
        }
    }

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMWorkLoadTypesbyFilter -Value Get-DMWorkLoadTypebyFilter
