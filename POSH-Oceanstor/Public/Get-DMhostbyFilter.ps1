function Get-DMhostbyFilter {
    <#
    .SYNOPSIS
        Searches for OceanStor hosts by a property filter.

    .DESCRIPTION
        Searches for hosts whose specified property matches the supplied keyword.
        When the filter matches a known API field (Id, Name), the query is pushed
        server-side to narrow the candidates transferred from the array. Other
        property names fall back to fetching the full host list, so prefer Id or
        Name when possible.

        Keyword supports PowerShell wildcards (*, ?, [...]). Per the OceanStor
        REST API reference, a single colon in "filter=field:value" requests a
        fuzzy (substring) match, while a double colon requests an exact match --
        confirmed live (host?filter=ID::5 returns exactly one host; ID:5 returns
        every host whose ID contains "5", e.g. 15, 51, 150). Without a wildcard,
        an exact double-colon query is sent. With a wildcard limited to a leading
        and/or trailing *, the literal middle is sent as a single-colon fuzzy hint
        to narrow the candidate set server-side. Any other wildcard shape (?, a
        [...] class, or a * in the middle) can't be expressed as a single fuzzy
        substring, so the full host list is fetched instead. Either way, the
        exact requested pattern is always re-verified client-side (-Like) before
        enrichment, so a broader-than-necessary server-side result only costs
        extra candidates transferred, never a wrong final result.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Filter
        Mandatory property name to filter against. Validated against OceanStorHost's actual properties before any REST call is made; an unrecognized name throws immediately.

    .PARAMETER Keyword
        Mandatory value to match against the chosen property. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide filter values by property name.

    .OUTPUTS
        OceanStorHost

        Returns host objects matching the requested property filter and keyword.

    .EXAMPLE

        PS C:\> Get-DMhostbyFilter -WebSession $session -Filter Id -Keyword 'host-01'

        OR

        PS C:\> $hosts = Get-DMhostbyFilter -Filter Name -Keyword 'esx01'

        OR

        PS C:\> $hosts = Get-DMhostbyFilter -Filter Name -Keyword 'esx*'

    .NOTES
        Filename: Get-DMhostbyFilter.ps1

    .LINK
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # A private-function or class-type-literal reference here would not resolve when the
                # real completion engine invokes this scriptblock (confirmed empirically); only calling
                # an already-public command like Get-DMhost works, so property names are read off one
                # live sample object instead of reflecting on the class directly.
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhost -WebSession $session | Select-Object -First 1).PSObject.Properties.Name |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Filter,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Keyword
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter $Filter

    # Map friendly property names to API field names for server-side filtering,
    # used only to narrow the candidate set transferred from the array. The
    # exact requested pattern is always re-verified client-side below, so an
    # imprecise server-side narrowing only costs extra candidates, not correctness.
    $PropertyToApiField = @{
        'Id'   = 'ID'
        'Name' = 'NAME'
    }

    $apiField = $PropertyToApiField[$Filter]
    $hasWildcard = $Keyword -match '[*?\[\]]'

    if ($apiField -and -not $hasWildcard) {
        # No wildcard: request an exact match server-side (double colon).
        $resource = "host?filter=$($apiField)::$([uri]::EscapeDataString($Keyword))"
    }
    elseif ($apiField -and $Keyword -match '^\*?([^*?\[\]]+)\*?$') {
        # Wildcard limited to a leading/trailing *: the middle is a literal
        # substring, safe to send as a fuzzy (single colon) narrowing hint.
        $resource = "host?filter=$($apiField):$([uri]::EscapeDataString($Matches[1]))"
    }
    else {
        # Unmapped field, or a wildcard shape the array's fuzzy filter can't
        # express as one substring (?, a [...] class, or a * in the middle).
        $resource = "host"
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Operation System", "Parent Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $hosts = New-Object System.Collections.ArrayList

    foreach ($thost in $response) {
        $hostobj = [OceanStorHost]::new($thost, $session)
        [void]$hosts.Add($hostobj)
    }

    # Always re-verify against the exact requested pattern client-side, even
    # after a server-side filter. -Like enforces the full wildcard pattern when
    # Keyword has one, and behaves as an exact match when it doesn't.
    $hosts = @($hosts | Where-Object $Filter -Like $Keyword)

    # Enrich only the filtered result, not the full unfiltered list, to avoid
    # paying the per-host initiator lookup cost for hosts that don't match.
    $hosts = @(Set-DMHostInitiator -InputObject $hosts -WebSession $session)

    $hosts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $hosts
}

Set-Alias -Name Get-DMhostsbyFilter -Value Get-DMhostbyFilter
