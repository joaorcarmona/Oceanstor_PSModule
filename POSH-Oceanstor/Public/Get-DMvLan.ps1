function Get-DMvLan {
    <#
	.SYNOPSIS
		To Get Huawei OceanStor Storage VLANs

	.DESCRIPTION
		Function to request configured Huawei OceanStor VLANs.
		Supports server-side narrowing: -Name uses the documented NAME filter
		(exact '::' match, or fuzzy ':' for simple leading/trailing wildcards)
		and -Id uses the documented vlan/${id} single-object query.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Id
		ID of a single VLAN to return (documented vlan/${id} GET).

	.PARAMETER Name
		VLAN name to filter by. Supports * wildcards; the exact pattern is
		always re-checked client-side after any server-side filter.

	.PARAMETER Tag
		VLAN tag ID to filter by (documented TAG filter field). Sent
		server-side and composes with the other filter parameters.

	.PARAMETER FatherDrvType
		Parent port driver type to filter by (documented fatherDrvType filter
		field). Sent server-side and composes with the other filter parameters.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorvLan

		Returns VLAN objects.

	.EXAMPLE

		PS C:\> Get-DMvLan -webSession $session

		OR

		PS C:\> $vlans = Get-DMvLan

	.EXAMPLE

		PS C:\> Get-DMvLan -Name 'CTE0.A*'

		OR

		PS C:\> Get-DMvLan -Id '4261543936'

	.NOTES
		Filename: Get-DMvLan.ps1

	.LINK
	#>
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
        [string]$Name,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$Tag,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$FatherDrvType
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Vlan Tag Id", "Port Type", "Running Status"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = "vlan"

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $resource = "vlan/$([uri]::EscapeDataString($Id))"
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
            # VLAN is fetched and the client-side -Like re-check below narrows it down.
        }

        if ($PSBoundParameters.ContainsKey('Tag')) {
            $clauses.Add("TAG::$([uri]::EscapeDataString($Tag))")
        }
        if ($PSBoundParameters.ContainsKey('FatherDrvType')) {
            $clauses.Add("fatherDrvType::$([uri]::EscapeDataString($FatherDrvType))")
        }

        if ($clauses.Count -gt 0) {
            $resource += "?filter=$($clauses -join ' and ')"
        }
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $vlans = New-Object System.Collections.ArrayList

    foreach ($tvlan in @($response)) {
        if ($null -eq $tvlan) { continue }
        $vlan = [OceanStorvLan]::new($tvlan, $session)
        [void]$vlans.Add($vlan)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $vlans = [System.Collections.ArrayList]@($vlans | Where-Object Name -Like $Name)
    }

    $vlans | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $vlans
    return $result
}

Set-Alias -Name Get-DMvLans -Value Get-DMvLan
