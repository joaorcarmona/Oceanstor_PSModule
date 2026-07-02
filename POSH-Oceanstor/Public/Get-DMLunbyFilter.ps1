function Get-DMLunbyFilter {
    <#
    .SYNOPSIS
        Searches for LUNs by a property filter.

    .DESCRIPTION
        Searches for LUNs whose specified property matches the supplied keyword.
        When the filter matches a known API field (Name, Id, WWN, Description,
        Storage Pool Name), the query is pushed server-side to narrow the
        candidates transferred from the array. Other property names fall back to
        fetching the full LUN list.

        Keyword supports PowerShell wildcards (*, ?, [...]). Per the OceanStor
        REST API reference, a single colon in "filter=field:value" requests a
        fuzzy (substring) match, while a double colon requests an exact match --
        confirmed live on the equivalent host filter (host?filter=ID::5 returns
        exactly one host; ID:5 returns every host whose ID contains "5"). Without
        a wildcard, an exact double-colon query is sent. With a wildcard limited
        to a leading and/or trailing *, the literal middle is sent as a
        single-colon fuzzy hint to narrow the candidate set server-side. Any
        other wildcard shape (?, a [...] class, or a * in the middle) can't be
        expressed as a single fuzzy substring, so the full LUN list is fetched
        instead. Either way, the exact requested pattern is always re-verified
        client-side (-Like), so a broader-than-necessary server-side result only
        costs extra candidates transferred, never a wrong final result.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Filter
        Mandatory property name to filter against. Validated against the connected array's LUN class properties (OceanstorLunv3 or OceanstorLunv6, depending on array version) before any REST call is made; an unrecognized name throws immediately.

    .PARAMETER Keyword
        Mandatory value to match against the chosen property. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide filter values by property name.

    .OUTPUTS
        OceanstorLunv3
        OceanstorLunv6

        Returns LUN objects matching the requested property filter and keyword.

    .EXAMPLE

        PS C:\> Get-DMLunbyFilter -webSession $session -Filter WWN -Keyword "6a08cf810075766e1efc050700000005"

        OR

        PS C:\> $luns = Get-DMLunbyFilter -Filter Name -Keyword "finance"

        OR

        PS C:\> $luns = Get-DMLunbyFilter -Filter Name -Keyword "finance*"

    .NOTES
        Filename: Get-DMLunbyFilter.ps1

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
                Get-DMLunFilterableProperty | Where-Object { $_ -like "$wordToComplete*" }
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

    $StorageVersion = $session.version.Substring(0, 2)
    $LunObjectClass = if ($StorageVersion -eq "V6") { [OceanstorLunv6] } else { [OceanstorLunv3] }

    Assert-DMValidFilterProperty -Type $LunObjectClass -Filter $Filter

    # Map friendly property names to API field names for server-side filtering,
    # used only to narrow the candidate set transferred from the array. The
    # exact requested pattern is always re-verified client-side below, so an
    # imprecise server-side narrowing only costs extra candidates, not correctness.
    $PropertyToApiField = @{
        'Name'              = 'NAME'
        'Id'                = 'ID'
        'WWN'               = 'WWN'
        'Description'       = 'DESCRIPTION'
        'Storage Pool Name' = 'PARENTNAME'
    }

    $apiField = $PropertyToApiField[$Filter]
    $hasWildcard = $Keyword -match '[*?\[\]]'

    if ($apiField -and -not $hasWildcard) {
        # No wildcard: request an exact match server-side (double colon).
        $resource = "lun?filter=$($apiField)::$([uri]::EscapeDataString($Keyword))"
    }
    elseif ($apiField -and $Keyword -match '^\*?([^*?\[\]]+)\*?$') {
        # Wildcard limited to a leading/trailing *: the middle is a literal
        # substring, safe to send as a fuzzy (single colon) narrowing hint.
        $resource = "lun?filter=$($apiField):$([uri]::EscapeDataString($Matches[1]))"
    }
    else {
        # Unmapped field, or a wildcard shape the array's fuzzy filter can't
        # express as one substring (?, a [...] class, or a * in the middle).
        $resource = "lun"
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $StorageLuns = New-Object System.Collections.ArrayList

    foreach ($tlun in $response) {
        $lun = $LunObjectClass::new($tlun, $session)
        [void]$StorageLuns.Add($lun)
    }

    # Always re-verify against the exact requested pattern client-side, even
    # after a server-side filter. -Like enforces the full wildcard pattern when
    # Keyword has one, and behaves as an exact match when it doesn't.
    $StorageLuns = @($StorageLuns | Where-Object $Filter -Like $Keyword)

    $StorageLuns | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $StorageLuns
}

Set-Alias -Name Get-DMLunsbyFilter -Value Get-DMLunbyFilter
