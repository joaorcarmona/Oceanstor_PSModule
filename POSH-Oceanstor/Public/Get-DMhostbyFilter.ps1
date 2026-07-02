function Get-DMhostbyFilter {
    <#
    .SYNOPSIS
        Searches for OceanStor hosts by a property filter.

    .DESCRIPTION
        Searches for hosts whose specified property equals the supplied keyword.
        When the filter matches a known API field (Id, Name), the query is pushed
        server-side to narrow the candidates transferred from the array. Other
        property names fall back to fetching the full host list, so prefer Id or
        Name when possible. Either way, an exact match is always re-verified
        client-side before enrichment, because the array's server-side filter is
        not reliably exact for every field -- confirmed live that filtering hosts
        by Id matches on substring (e.g. Id "5" also matches "15", "51", "150"),
        while Name is an exact match.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Filter
        Mandatory property name to filter against. The value must be a valid host object property.

    .PARAMETER Keyword
        Mandatory value to match against the chosen property. The comparison is an exact match.

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

    .NOTES
        Filename: Get-DMhostbyFilter.ps1

    .LINK
    #>
    [Cmdletbinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
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

    # Map friendly property names to API field names for server-side filtering,
    # used only to narrow the candidate set transferred from the array -- not
    # trusted for exact matching. Confirmed live that the array's ID filter does
    # a substring match, not exact (filter=ID:5 returned every host whose ID
    # contains "5", e.g. 5, 15, 25, 51, 59, 150-159); NAME was confirmed exact.
    # An exact client-side match is always applied below regardless, so a
    # substring-matching field here only costs extra candidates, not correctness.
    $PropertyToApiField = @{
        'Id'   = 'ID'
        'Name' = 'NAME'
    }

    $apiField = $PropertyToApiField[$Filter]
    if ($apiField) {
        $resource = "host?filter=$($apiField):$([uri]::EscapeDataString($Keyword))"
    }
    else {
        $resource = "host"
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Operation System", "Parent Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $hosts = New-Object System.Collections.ArrayList

    foreach ($thost in $response) {
        $hostobj = [OceanStorHost]::new($thost, $session)
        [void]$hosts.Add($hostobj)
    }

    # Always re-verify with an exact match client-side, even after a server-side
    # filter -- the array's filter semantics vary by field (see note above) and
    # cannot be trusted alone.
    $hosts = @($hosts | Where-Object $Filter -EQ $Keyword)

    # Enrich only the filtered result, not the full unfiltered list, to avoid
    # paying the per-host initiator lookup cost for hosts that don't match.
    $hosts = @(Set-DMHostInitiator -InputObject $hosts -WebSession $session)

    $hosts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $hosts
}

Set-Alias -Name Get-DMhostsbyFilter -Value Get-DMhostbyFilter
