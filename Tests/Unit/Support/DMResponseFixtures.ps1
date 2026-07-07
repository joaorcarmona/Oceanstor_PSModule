# Shared OceanStor v6 REST-response fixture library for unit test suites.
# Dot-source this file into the suite's test module (same convention as
# Assert-DMWhatIfSafe.ps1) to build canonical success/error/paged response
# envelopes and sanitized sample objects instead of hand-rolling them per file.
#
# Sanitization rule: every sample object in this file uses obviously-fake
# values (POSHTEST-* names/IDs, RFC 5737 TEST-NET-1 addresses, made-up
# WWN/IQN strings). Never copy real lab hostnames, serials, WWNs, IQNs, NQNs,
# MACs, or the lab array IP into this file.

function New-DMFixtureSuccessResponse {
    param(
        [int]$Code = 0,
        [string]$Description = '',

        $Data
    )

    $response = [pscustomobject]@{
        error = [pscustomobject]@{ Code = $Code; description = $Description }
    }

    if ($PSBoundParameters.ContainsKey('Data')) {
        $response | Add-Member -NotePropertyName data -NotePropertyValue $Data
    }

    $response
}

function New-DMFixtureErrorResponse {
    param(
        [Parameter(Mandatory)]
        [int]$Code,

        [string]$Description = ''
    )

    [pscustomobject]@{
        error = [pscustomobject]@{ Code = $Code; description = $Description }
    }
}

function New-DMFixtureSessionExpiredResponse {
    New-DMFixtureErrorResponse -Code 1077939726 -Description 'session expired'
}

function New-DMFixtureEmptyResponse {
    New-DMFixtureSuccessResponse -Data @()
}

function New-DMFixturePagedResponse {
    param(
        [Parameter(Mandatory)]
        [array]$Items,

        [Parameter(Mandatory)]
        [int]$Start,

        [Parameter(Mandatory)]
        [int]$End
    )

    $lastIndex = [Math]::Min($End, $Items.Count) - 1
    $page = if ($Start -gt $lastIndex) { @() } else { @($Items[$Start..$lastIndex]) }

    New-DMFixtureSuccessResponse -Data $page
}

function New-DMFixtureIdenticalPageResponse {
    param(
        [Parameter(Mandatory)]
        [array]$Items
    )

    # Intentionally returns the same full page every time it is called; wire
    # this into a Mock so Invoke-DMPagedRequest's identical-full-page
    # loop-protection path can be exercised without hand-building the page
    # twice.
    New-DMFixtureSuccessResponse -Data @($Items)
}

function New-DMFixtureLun {
    param(
        [string]$Id = 'POSHTEST-LUN01',
        [string]$Name = 'poshtest-lun',
        [string]$Wwn = '2100000000000000',
        [string]$ParentId = 'POSHTEST-POOL01',
        [string]$ParentName = 'poshtest-pool',
        [long]$Capacity = 2097152,
        [long]$AllocCapacity = 1048576,
        [int]$HealthStatus = 1,
        [int]$RunningStatus = 27
    )

    [pscustomobject]@{
        ID            = $Id
        NAME          = $Name
        WWN           = $Wwn
        PARENTID      = $ParentId
        PARENTNAME    = $ParentName
        TYPE          = 11
        SECTORSIZE    = 512
        CAPACITY      = $Capacity
        ALLOCCAPACITY = $AllocCapacity
        HEALTHSTATUS  = $HealthStatus
        RUNNINGSTATUS = $RunningStatus
        ALLOCTYPE     = 1
    }
}

function New-DMFixtureHost {
    param(
        [string]$Id = 'POSHTEST-HOST01',
        [string]$Name = 'poshtest-host',
        [string]$Iqn = 'iqn.1993-08.org.debian:01:poshtest',
        [int]$HealthStatus = 1,
        [int]$RunningStatus = 1
    )

    [pscustomobject]@{
        ID            = $Id
        NAME          = $Name
        OPERATIONSYSTEM = 0
        INITIATORIQN  = $Iqn
        HEALTHSTATUS  = $HealthStatus
        RUNNINGSTATUS = $RunningStatus
    }
}

function New-DMFixtureFileSystem {
    param(
        [string]$Id = 'POSHTEST-FS01',
        [string]$Name = 'poshtest-fs',
        [long]$Capacity = 2097152,
        [long]$AllocCapacity = 0,
        [int]$HealthStatus = 1,
        [int]$RunningStatus = 27
    )

    [pscustomobject]@{
        ID            = $Id
        NAME          = $Name
        SECTORSIZE    = 512
        CAPACITY      = $Capacity
        ALLOCCAPACITY = "$AllocCapacity"
        HEALTHSTATUS  = $HealthStatus
        RUNNINGSTATUS = $RunningStatus
    }
}

function New-DMFixtureNetworkObject {
    param(
        [string]$Id = 'POSHTEST-LIF01',
        [string]$Name = 'poshtest-lif',
        [string]$IpAddress = '192.0.2.10',
        [string]$HomePortId = 'POSHTEST-PORT01',
        [int]$HealthStatus = 1,
        [int]$RunningStatus = 27
    )

    [pscustomobject]@{
        ID            = $Id
        NAME          = $Name
        IPV4ADDR      = $IpAddress
        HOMEPORTID    = $HomePortId
        HEALTHSTATUS  = $HealthStatus
        RUNNINGSTATUS = $RunningStatus
    }
}

function New-DMFixtureReplicationObject {
    param(
        [string]$Id = 'POSHTEST-HM01',
        [string]$Name = 'poshtest-hm-pair',
        [string]$LocalResId = 'POSHTEST-LUN01',
        [string]$RemoteResId = 'POSHTEST-LUN02',
        [int]$HealthStatus = 1,
        [int]$RunningStatus = 1
    )

    [pscustomobject]@{
        ID            = $Id
        NAME          = $Name
        LOCALRESID    = $LocalResId
        REMOTERESID   = $RemoteResId
        HEALTHSTATUS  = $HealthStatus
        RUNNINGSTATUS = $RunningStatus
    }
}

function New-DMExactFilterResource {
    param(
        [Parameter(Mandatory)]
        [string]$Resource,

        [Parameter(Mandatory)]
        [string]$Property,

        [Parameter(Mandatory)]
        [string]$Value
    )

    "${Resource}?filter=${Property}::${Value}*"
}

function New-DMFuzzyFilterResource {
    param(
        [Parameter(Mandatory)]
        [string]$Resource,

        [Parameter(Mandatory)]
        [string]$Property,

        [Parameter(Mandatory)]
        [string]$Value
    )

    "${Resource}?filter=${Property}:${Value}*"
}

function New-DMRangeResourcePattern {
    param(
        [Parameter(Mandatory)]
        [string]$Resource,

        [Parameter(Mandatory)]
        [int]$Start,

        [Parameter(Mandatory)]
        [int]$End
    )

    $separator = if ($Resource.Contains('?')) { '&' } else { '?' }
    "$Resource$separator" + "range=[$Start-$End]*"
}
