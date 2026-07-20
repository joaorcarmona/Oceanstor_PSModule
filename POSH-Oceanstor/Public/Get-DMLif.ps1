function Get-DMLif {
    <#
	.SYNOPSIS
		To Get Huawei OceanStor Storage LIFs

	.DESCRIPTION
		Function to request configured Huawei OceanStor logical interfaces.
		Supports server-side narrowing: -Name uses the documented NAME filter
		(exact '::' match, or fuzzy ':' for simple leading/trailing wildcards)
		and -Id uses the documented lif/${id} single-object query.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Id
		ID of a single logical interface to return (documented lif/${id} GET).

	.PARAMETER Name
		Logical interface name to filter by. Supports * wildcards; the exact
		pattern is always re-checked client-side after any server-side filter.

	.PARAMETER Ipv4Addr
		IPv4 address to filter by (documented IPV4ADDR filter field). Sent
		server-side and composes with the other filter parameters.

	.PARAMETER Ipv6Addr
		IPv6 address to filter by (documented IPV6ADDR filter field). Sent
		server-side and composes with the other filter parameters.

	.PARAMETER HomePortId
		Home port ID to filter by (documented HOMEPORTID filter field). Sent
		server-side and composes with the other filter parameters.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorLIF

		Returns logical interface objects.

	.EXAMPLE

		PS C:\> Get-DMLif -webSession $session

		OR

		PS C:\> $lifs = Get-DMLif

	.EXAMPLE

		PS C:\> Get-DMLif -Name 'nas_lif*'

		OR

		PS C:\> Get-DMLif -Id '657expr000'

	.NOTES
		Filename: Get-DMLif.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [Cmdletbinding(DefaultParameterSetName = 'All')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Position = 0, ParameterSetName = 'ByName')]
        [ValidateLength(1, 255)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMLif -WebSession $session).'LIF Name' | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$Ipv4Addr,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$Ipv6Addr,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$HomePortId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "LIF Name", "IPv4 Address", "Running Status", "Support Protocol"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = "lif"

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $resource = "lif/$([uri]::EscapeDataString($Id))"
    }
    else {
        # Build documented filter clauses and AND-join them, matching the
        # field::value syntax used by the other filterable getters.
        $clauses = New-Object System.Collections.Generic.List[string]

        if ($Name) {
            $hasWildcard = $Name -match '[*?\[\]]'
            if (-not $hasWildcard) {
                # No wildcard: request an exact match server-side (double colon).
                $clauses.Add("NAME::$([uri]::EscapeDataString($Name))")
            }
            elseif ($Name -match '^\*?([^*?\[\]]+)\*?$') {
                # Wildcard limited to a leading/trailing *: the middle is a literal
                # substring, safe to send as a fuzzy (single colon) narrowing hint.
                $clauses.Add("NAME:$([uri]::EscapeDataString($Matches[1]))")
            }
            # Any other wildcard shape (?, a [...] class, or a * in the middle) can't
            # be expressed as one fuzzy substring, so no NAME filter is sent -- every
            # LIF is fetched and the client-side -Like re-check below narrows it down.
        }

        if ($PSBoundParameters.ContainsKey('Ipv4Addr')) {
            $clauses.Add("IPV4ADDR::$([uri]::EscapeDataString($Ipv4Addr))")
        }
        if ($PSBoundParameters.ContainsKey('Ipv6Addr')) {
            $clauses.Add("IPV6ADDR::$([uri]::EscapeDataString($Ipv6Addr))")
        }
        if ($PSBoundParameters.ContainsKey('HomePortId')) {
            $clauses.Add("HOMEPORTID::$([uri]::EscapeDataString($HomePortId))")
        }

        if ($clauses.Count -gt 0) {
            $resource += "?filter=$($clauses -join ' and ')"
        }
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $lifs = New-Object System.Collections.ArrayList

    foreach ($tlif in @($response)) {
        if ($null -eq $tlif) { continue }
        $lif = [OceanStorLIF]::new($tlif, $session)
        [void]$lifs.Add($lif)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $lifs = [System.Collections.ArrayList]@($lifs | Where-Object 'LIF Name' -Like $Name)
    }

    $lifs | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $lifs
    return $result
}

Set-Alias -Name Get-DMLifs -Value Get-DMLif
