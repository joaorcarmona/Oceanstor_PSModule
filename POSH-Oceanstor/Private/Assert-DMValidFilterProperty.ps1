function Assert-DMValidFilterProperty {
    <#
    .SYNOPSIS
        Throws when -Filter does not name a real property of the given class.

    .DESCRIPTION
        Uses Get-DMFilterableProperty to get Type's real property names -- the same
        set a constructed object would expose to Where-Object/Get-Member -- and
        throws if Filter isn't one of them. Nothing about the valid property set is
        hardcoded here: it's derived from whichever class the caller passes in, so
        any current or future OceanStor object class works without touching this
        function.

        This only validates that Filter names a real property; it says nothing about
        whether that property can be pushed server-side as a REST filter=field -- that
        remains a separate, per-command, empirically-verified concern (a "known API
        field" map), since reflection has no way to know what the array's filter=
        query parameter actually accepts.

    .PARAMETER Type
        The class to validate Filter's property against, e.g. [OceanStorHost].

    .PARAMETER Filter
        The property name supplied by the caller.

    .NOTES
        Filename: Assert-DMValidFilterProperty.ps1
    #>
    param(
        [Parameter(Mandatory)]
        [type]$Type,

        [Parameter(Mandatory)]
        [string]$Filter
    )

    $validNames = Get-DMFilterableProperty -Type $Type

    if ($Filter -notin $validNames) {
        throw "Invalid Filter '$Filter'. Valid properties for $($Type.Name) are: $($validNames -join ', ')"
    }
}
