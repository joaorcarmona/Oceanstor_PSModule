function Get-DMstoragePool {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Pools Configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Pools Configured in the system. With no
		arguments, returns every storage pool. When Name is supplied (positionally or named),
		filters server-side: an exact match when Name has no wildcard, a fuzzy substring hint
		when Name has a leading and/or trailing * (per OceanStor REST API reference: a single
		colon in filter=field:value requests a fuzzy match, a double colon requests an exact
		match). Any other wildcard shape falls back to fetching every pool and filtering
		client-side. Either way the exact requested pattern is always re-verified client-side
		(-Like) before returning, so an imprecise server-side result never produces a wrong
		final answer.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Name
		Optional storage pool name to search for, positional. If omitted, every storage pool is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorStoragePool

		Returns storage pool objects.

	.EXAMPLE

		PS C:\> Get-DMstoragePool -webSession $session

		OR

		PS C:\> $StoragePools = Get-DMstoragePool

	.EXAMPLE

		PS C:\> Get-DMstoragePool 'performance'

		OR

		PS C:\> Get-DMstoragePool 'perf*'

	.NOTES
		Filename: Get-DMstoragePool.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Name
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Total Capacity (GB)", "Free Capacity (GB)"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'storagepool'

    if ($Name) {
        $hasWildcard = $Name -match '[*?\[\]]'
        if (-not $hasWildcard) {
            # No wildcard: request an exact match server-side (double colon).
            $resource += "?filter=NAME::$([uri]::EscapeDataString($Name))"
        }
        elseif ($Name -match '^\*?([^*?\[\]]+)\*?$') {
            # Wildcard limited to a leading/trailing *: the middle is a literal
            # substring, safe to send as a fuzzy (single colon) narrowing hint.
            $resource += "?filter=NAME:$([uri]::EscapeDataString($Matches[1]))"
        }
        # Any other wildcard shape (?, a [...] class, or a * in the middle) can't be
        # expressed as one fuzzy substring, so no filter is sent -- every pool is
        # fetched and the client-side -Like re-check below narrows it down.
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $storagePools = New-Object System.Collections.ArrayList

    foreach ($spool in $response) {
        $storagepool = [OceanStorStoragePool]::new($spool, $session)
        [void]$storagePools.Add($storagepool)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $storagePools = [System.Collections.ArrayList]@($storagePools | Where-Object Name -Like $Name)
    }

    $storagePools | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $storagePools

    return $result
}

Set-Alias -Name Get-DMstoragePools -Value Get-DMstoragePool
