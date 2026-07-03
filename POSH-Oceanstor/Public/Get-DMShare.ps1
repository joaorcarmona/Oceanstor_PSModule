function Get-DMShare {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Shares

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Shares. With no Name argument, returns
		every share of the requested shareType. When Name is supplied (positionally or
		named), filters server-side: an exact match when Name has no wildcard, a fuzzy
		substring hint when Name has a leading and/or trailing * (per OceanStor REST API
		reference: a single colon in filter=field:value requests a fuzzy match, a double
		colon requests an exact match). Any other wildcard shape falls back to fetching
		every share and filtering client-side. Either way the exact requested pattern is
		always re-verified client-side (-Like) before returning.

		For CIFS shares, Name matches against the share's Name field, which the REST API
		supports filtering on directly. For NFS shares, the underlying NFSHARE REST
		resource does not support filtering (or reliably populating) the NAME field at
		all -- it is documented as unsupported and typically blank -- so for
		shareType NFS, Name instead matches against Share Path (SHAREPATH), which is the
		only reliably filterable identifying field NFS shares expose. This means
		Get-DMShare -shareType NFS -Name searches share paths, not share names.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Name
		Optional share name to search for, positional. If omitted, every share of the requested shareType is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match. For shareType NFS, this matches against Share Path instead of Name, since the OceanStor REST API does not support filtering NFS shares by Name.

	.PARAMETER shareType
		Mamdatory paramter to define the Share Type to Query ("NFS","CIFS")

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide shareType by property name.

	.OUTPUTS
		OceanStorCIFSShare
		OceanStorNFSShare

		Returns CIFS or NFS share objects, depending on shareType.

	.EXAMPLE

		PS C:\> Get-DMShare -webSession $session -shareType CIFS

		OR

		PS C:\> $shares = Get-DMShare -shareType NFS

	.EXAMPLE

		PS C:\> Get-DMShare 'finance' -shareType CIFS

		OR

		PS C:\> Get-DMShare '/finance/*' -shareType NFS

	.NOTES
		Filename: Get-DMShare.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Name,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateSet("CIFS", "NFS")]
        [string]$shareType
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Share Path", "FileSystem ID", "vStore Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    switch ($shareType) {
        CIFS {
            $resourceQuery = "CIFSHARE"
            $filterField = 'NAME'
        }
        NFS {
            $resourceQuery = "NFSHARE"
            # NFSHARE's NAME field is documented as unsupported/unpopulated; SHAREPATH
            # is the only reliably filterable identifying field for NFS shares.
            $filterField = 'SHAREPATH'
        }
    }

    if ($Name) {
        $hasWildcard = $Name -match '[*?\[\]]'
        if ($shareType -eq 'CIFS' -and -not $hasWildcard) {
            # No wildcard: request an exact match server-side (double colon). Only
            # attempted for CIFS -- SHAREPATH is documented as fuzzy-match only.
            $resourceQuery += "?filter=${filterField}::$([uri]::EscapeDataString($Name))"
        }
        elseif ($Name -match '^\*?([^*?\[\]]+)\*?$') {
            # Wildcard limited to a leading/trailing *: the middle is a literal
            # substring, safe to send as a fuzzy (single colon) narrowing hint. Also
            # covers every NFS request, since SHAREPATH only supports fuzzy matching.
            $resourceQuery += "?filter=${filterField}:$([uri]::EscapeDataString($Matches[1]))"
        }
        # Any other wildcard shape (?, a [...] class, or a * in the middle) can't be
        # expressed as one fuzzy substring, so no filter is sent -- every share is
        # fetched and the client-side -Like re-check below narrows it down.
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resourceQuery
    $shares = New-Object System.Collections.ArrayList

    foreach ($tshare in $response) {
        switch ($shareType) {
            CIFS {
                $share = [OceanStorCIFSShare]::new($tshare, $session)
            }
            NFS {
                $share = [OceanStorNFSShare]::new($tshare, $session)
            }
        }

        [void]$shares.Add($share)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even after
        # a server-side filter. -Like enforces the full wildcard pattern when Name has
        # one, and behaves as an exact match when it doesn't. NFS shares are matched
        # against Share Path, mirroring the server-side filter field used above.
        $matchProperty = if ($shareType -eq 'NFS') { 'Share Path' } else { 'Name' }
        $shares = [System.Collections.ArrayList]@($shares | Where-Object $matchProperty -Like $Name)
    }

    $shares | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $shares
    return $result
}

Set-Alias -Name Get-DMShares -Value Get-DMShare
