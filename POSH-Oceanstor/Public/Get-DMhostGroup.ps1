function Get-DMhostGroup {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Host Groups

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Host Groups

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Name
		Optional host group name to search for, positional. When omitted, every host group is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

	.PARAMETER Id
		Optional host group ID to search for. Mutually exclusive with Name (enforced by parameter set). Returns exactly one host group, exact match only, no wildcard support.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorHostGroup

		Returns host group objects.

	.EXAMPLE

		PS C:\> Get-DMhostGroup -webSession $session

		OR

		PS C:\> $hostGroups = Get-DMhostGroup

	.EXAMPLE

		PS C:\> Get-DMhostGroup 'esx-cluster'

	.EXAMPLE

		PS C:\> Get-DMhostGroup -Id '3'

	.NOTES
		Filename: Get-DMhostGroup.ps1

	.LINK
	#>
    [Cmdletbinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 1, Mandatory = $false)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [string]$VstoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Is Mapped", "Host Member Number", "vStore Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'hostgroup'
    $queryParams = [System.Collections.Generic.List[string]]::new()

    if ($Id) {
        # An ID is either an exact match or not found -- no fuzzy/wildcard use case.
        $queryParams.Add("filter=ID::$([uri]::EscapeDataString($Id))")
    }
    elseif ($Name) {
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

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $hostgroups = New-Object System.Collections.ArrayList

    foreach ($hgroup in $response) {
        $hostgroup = [OceanStorHostGroup]::new($hgroup, $session)
        [void]$hostgroups.Add($hostgroup)
    }

    if ($Id) {
        # Always re-verify client-side, even after a server-side filter.
        $hostgroups = [System.Collections.ArrayList]@($hostgroups | Where-Object Id -EQ $Id)
    }
    elseif ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $hostgroups = [System.Collections.ArrayList]@($hostgroups | Where-Object Name -Like $Name)
    }

    $hostgroups | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $hostgroups

    return $result
}

Set-Alias -Name Get-DMhostGroups -Value Get-DMhostGroup
