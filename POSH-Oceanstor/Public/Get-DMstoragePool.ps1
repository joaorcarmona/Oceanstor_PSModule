function Get-DMstoragePool {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Pools Configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Pools Configured in the system. With no
		arguments, returns every storage pool. Selection is done with one of two mutually
		exclusive parameter sets:

		- Name (positional, default): filters server-side by NAME. An exact match when Name has
		  no wildcard, a fuzzy substring hint when Name has a leading and/or trailing * (per
		  OceanStor REST API reference: a single colon in filter=field:value requests a fuzzy
		  match, a double colon an exact match). Any other wildcard shape falls back to fetching
		  every pool and filtering client-side. The exact requested pattern is always re-verified
		  client-side (-Like) before returning, so an imprecise server-side result never produces
		  a wrong final answer.
		- Id: filters server-side by ID with an exact match (no wildcard), re-verified client-side.

		Both Name and Id support tab completion of the connected array's existing pools.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Name
		Optional storage pool name to search for, positional. If omitted, every storage pool is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match. Tab completion offers existing storage pool names. Also accepts the alias -StoragePoolName.

	.PARAMETER Id
		Optional storage pool ID to search for. Returns exactly one pool, exact match only, no wildcard support. Tab completion offers existing storage pool IDs. Also accepts the alias -StoragePoolId.

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

		PS C:\> Get-DMstoragePool '*perf*'

	.EXAMPLE

		PS C:\> Get-DMstoragePool -Id '0'

	.NOTES
		Filename: Get-DMstoragePool.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Alias('StoragePoolName')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMstoragePool -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('StoragePoolId')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMstoragePool -WebSession $session).Id | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Id
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

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        # Id: exact match server-side (double colon); no wildcard support.
        $resource += "?filter=ID::$([uri]::EscapeDataString($Id))"
    }
    elseif ($Name) {
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

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        # Re-verify the exact ID client-side, even after the server-side filter.
        $storagePools = [System.Collections.ArrayList]@($storagePools | Where-Object Id -EQ $Id)
    }
    elseif ($Name) {
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
