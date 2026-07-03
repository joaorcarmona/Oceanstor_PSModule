function Get-DMPortGroup {
    <#
    .SYNOPSIS
        Retrieves OceanStor port groups.

    .DESCRIPTION
        Gets port groups from OceanStor, optionally scoped to a vStore. With no Name
        argument, returns every port group. When Name is supplied (positionally or
        named), filters server-side: an exact match when Name has no wildcard, a fuzzy
        substring hint when Name has a leading and/or trailing * (per OceanStor REST API
        reference: a single colon in filter=field:value requests a fuzzy match, a double
        colon requests an exact match). Any other wildcard shape falls back to fetching
        every port group and filtering client-side. Either way the exact requested
        pattern is always re-verified client-side (-Like) before returning, so an
        imprecise server-side result never produces a wrong final answer.
        Returned objects use the OceanstorPortGroup class and include a default display set for common port group properties.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Name
        Optional port group name to search for, positional. If omitted, every port group is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the port group query.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorPortGroup

    .EXAMPLE
        PS> Get-DMPortGroup 'fc-front-end'

        Returns the port group named fc-front-end.

    .EXAMPLE
        PS> Get-DMPortGroup 'fc-*'

        Returns port groups whose name starts with fc-.

    .EXAMPLE
        PS> Get-DMPortGroup -VstoreId '1'

        Returns port groups scoped to vStore ID 1.

    .NOTES
        Filename: Get-DMPortGroup.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Name,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $resource = 'portgroup'
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
        # expressed as one fuzzy substring, so no filter is sent -- every port group is
        # fetched and the client-side -Like re-check below narrows it down.
    }
    if ($VstoreId) {
        $queryParams.Add("vstoreId=$VstoreId")
    }
    if ($queryParams.Count -gt 0) {
        $resource += '?' + ($queryParams -join '&')
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource |
        Select-DMResponseData
    $defaultDisplaySet = 'Id', 'Name', 'Port Type', 'Port Count', 'Is Mapped', 'vStore Name'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $groups = [System.Collections.ArrayList]::new()

    foreach ($groupData in @($response)) {
        $group = [OceanstorPortGroup]::new($groupData, $session)
        [void]$groups.Add($group)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $groups = [System.Collections.ArrayList]@($groups | Where-Object Name -Like $Name)
    }

    $groups | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $groups
}
