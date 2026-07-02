function Get-DMlunGroup {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Lun Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Lun Groups. With no arguments,
		returns every LUN group. With Name supplied (positionally or named), filters
		by name server-side: an exact match when Name has no wildcard, a fuzzy
		substring hint when Name has a leading and/or trailing * (per the OceanStor
		REST API reference: a single colon in filter=field:value is a fuzzy match,
		a double colon is exact). Any other wildcard shape falls back to fetching
		every group and matching client-side. Either way the exact requested
		pattern is always re-verified client-side (-Like) before returning, so an
		imprecise server-side result never produces a wrong final answer.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Name
		Optional LUN group name to search for, positional. When omitted, every LUN group is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession by property name.

	.OUTPUTS
		OceanStorLunGroup

		Returns LUN group objects.

	.EXAMPLE

		PS C:\> Get-DMlunGroup -webSession $session

		OR

		PS C:\> $lunGroups = Get-DMlunGroup

	.EXAMPLE

		PS C:\> Get-DMlunGroup 'production-luns'

		OR

		PS C:\> Get-DMlunGroup 'production-*'

	.EXAMPLE

		PS C:\> $lunGroup = (Get-DMlunGroup -WebSession $session)[0]
		PS C:\> $memberLuns = $lunGroup.GetLuns()

	.NOTES
		Filename: Get-DMlunGroup.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Name,

        [string]$VstoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "LunGroup Capacity", "Is Mapped", "Luns Members number"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'lungroup'
    $queryParams = [System.Collections.Generic.List[string]]::new()

    if ($Name) {
        $hasWildcard = $Name -match '[*?\[\]]'
        if (-not $hasWildcard) {
            # No wildcard: request an exact match server-side (double colon).
            $queryParams.Add("filter=NAME::$([uri]::EscapeDataString($Name))")
        }
        elseif ($Name -match '^\*?([^*?\[\]]+)\*?$') {
            # Wildcard limited to a leading/trailing *: the middle is a literal
            # substring, safe to send as a fuzzy (single colon) narrowing hint.
            $queryParams.Add("filter=NAME:$([uri]::EscapeDataString($Matches[1]))")
        }
        # Any other wildcard shape (?, a [...] class, or a * in the middle) can't be
        # expressed as one fuzzy substring, so no filter is sent -- every group is
        # fetched and the client-side -Like re-check below narrows it down.
    }
    if ($VstoreId) {
        $queryParams.Add("vstoreId=$VstoreId")
    }
    if ($queryParams.Count -gt 0) {
        $resource += '?' + ($queryParams -join '&')
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $lunGroups = New-Object System.Collections.ArrayList

    foreach ($lgroup in $response) {
        $lunGroup = [OceanStorLunGroup]::new($lgroup, $session)
        [void]$lunGroups.Add($lunGroup)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $lunGroups = [System.Collections.ArrayList]@($lunGroups | Where-Object Name -Like $Name)
    }

    $lunGroups | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $lunGroups

    return $result
}

Set-Alias -Name Get-DMlunGroups -Value Get-DMlunGroup
