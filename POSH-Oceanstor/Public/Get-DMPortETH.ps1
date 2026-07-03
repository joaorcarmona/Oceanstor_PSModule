function Get-DMPortETH {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Ethernet Ports

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Ethernet Ports. With no
    arguments, returns every Ethernet port. When Name is supplied (positionally or
    named), filters server-side: an exact match when Name has no wildcard, a fuzzy
    substring hint when Name has a leading and/or trailing * (per OceanStor REST API
    reference: a single colon in filter=field:value requests a fuzzy match, a double
    colon requests an exact match). Any other wildcard shape falls back to fetching
    every port and filtering client-side. Either way the exact requested pattern is
    always re-verified client-side (-Like) before returning, so an imprecise
    server-side result never produces a wrong final answer.

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.PARAMETER Name
    Optional Ethernet port name to search for, positional. If omitted, every Ethernet port is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorPortETH

    Returns Ethernet port objects.

.EXAMPLE

    PS C:\> Get-DMPortETH -webSession $session

    OR

    PS C:\> $ethPorts = Get-DMPortETH

.EXAMPLE

    PS C:\> Get-DMPortETH 'CTE0.A.IOM0.P0'

    OR

    PS C:\> Get-DMPortETH 'CTE0.A.IOM0.*'

.NOTES
    Filename: Get-DMPortETH.ps1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "IPv4 Address"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = "eth_port"

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
        # expressed as one fuzzy substring, so no filter is sent -- every port is
        # fetched and the client-side -Like re-check below narrows it down.
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $ethPorts = New-Object System.Collections.ArrayList

    foreach ($peth in $response) {
        $ethpObj = [OceanStorPortETH]::new($peth, $session)
        [void]$ethPorts.Add($ethpObj)
    }

    if ($Name) {
        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Name has one, and behaves as an exact match when it doesn't.
        $ethPorts = [System.Collections.ArrayList]@($ethPorts | Where-Object Name -Like $Name)
    }

    $ethPorts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $ethPorts

    return $result
}
