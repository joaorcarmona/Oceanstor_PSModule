function Get-DMFileSystem {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage File Systems

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage File Systems. With no arguments, returns
		every file system. When Name is supplied (positionally or named), filters server-side:
		an exact match when Name has no wildcard, a fuzzy substring hint when Name has a
		leading and/or trailing * (per OceanStor REST API reference: a single colon in
		filter=field:value requests a fuzzy match, a double colon requests an exact match).
		Any other wildcard shape falls back to fetching every file system and filtering
		client-side. Either way the exact requested pattern is always re-verified client-side
		(-Like) before returning, so an imprecise server-side result never produces a wrong
		final answer.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Name
		Optional file system name to search for, positional. If omitted, every file system is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanstorFileSystem

		Returns file system objects.

	.EXAMPLE

		PS C:\> Get-DMFileSystem -webSession $session

		OR

		PS C:\> $FileSystems = Get-DMFileSystem

	.EXAMPLE

		PS C:\> Get-DMFileSystem 'documents'

		OR

		PS C:\> Get-DMFileSystem 'doc*'

	.NOTES
		Filename: Get-DMFileSystem.ps1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Capacity (GB)"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'filesystem'

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
        # expressed as one fuzzy substring, so no filter is sent -- every file system is
        # fetched and the client-side -Like re-check below narrows it down.
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $FileSystems = New-Object System.Collections.ArrayList

    foreach ($fs in $response) {
        $fileSystem = [OceanstorFileSystem]::new($fs, $session)
        [void]$FileSystems.Add($fileSystem)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $FileSystems = [System.Collections.ArrayList]@($FileSystems | Where-Object Name -Like $Name)
    }

    $FileSystems | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $FileSystems

    return $result
}
