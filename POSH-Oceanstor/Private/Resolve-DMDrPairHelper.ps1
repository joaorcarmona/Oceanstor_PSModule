function ConvertTo-DMReplicationModeCode {
    param([string]$Value)
    switch ($Value) {
        'Sync' { return '1' }
        'Async' { return '2' }
        default { return $Value }
    }
}

function ConvertTo-DMDrRecoveryPolicyCode {
    param([string]$Value)
    switch ($Value) {
        'Automatic' { return '1' }
        'Manual' { return '2' }
        default { return $Value }
    }
}

function ConvertTo-DMDrSpeedCode {
    param([string]$Value)
    switch ($Value) {
        'Low' { return '1' }
        'Medium' { return '2' }
        'High' { return '3' }
        'Highest' { return '4' }
        default { return $Value }
    }
}

function ConvertTo-DMReplicationSynchronizationTypeCode {
    param([string]$Value)
    switch ($Value) {
        'Manual' { return '1' }
        'TimedWaitAfterStart' { return '2' }
        'TimedWaitAfterSync' { return '3' }
        'SpecificTimePolicy' { return '4' }
        default { return $Value }
    }
}

function Resolve-DMReplicationPairId {
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        return $Id
    }

    $matches = @(Get-DMReplicationPair -WebSession $WebSession -Name $Name)
    if ($matches.Count -eq 1) {
        return $matches[0].Id
    }
    if ($matches.Count -gt 1) {
        throw "Replication pair name '$Name' is ambiguous."
    }
    throw "Replication pair '$Name' was not found."
}

function Resolve-DMHyperMetroPairId {
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        return $Id
    }

    $matches = @(Get-DMHyperMetroPair -WebSession $WebSession -Name $Name)
    if ($matches.Count -eq 1) {
        return $matches[0].Id
    }
    if ($matches.Count -gt 1) {
        throw "HyperMetro pair name '$Name' is ambiguous."
    }
    throw "HyperMetro pair '$Name' was not found."
}

function Resolve-DMHyperMetroDomainId {
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        return $Id
    }

    $matches = @(Get-DMHyperMetroDomain -WebSession $WebSession -Name $Name)
    if ($matches.Count -eq 1) {
        return $matches[0].Id
    }
    if ($matches.Count -gt 1) {
        throw "HyperMetro domain name '$Name' is ambiguous."
    }
    throw "HyperMetro domain '$Name' was not found."
}

function Resolve-DMReplicationConsistencyGroupId {
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        return $Id
    }

    $matches = @(Get-DMReplicationConsistencyGroup -WebSession $WebSession -Name $Name)
    if ($matches.Count -eq 1) {
        return $matches[0].Id
    }
    if ($matches.Count -gt 1) {
        throw "Replication consistency group name '$Name' is ambiguous."
    }
    throw "Replication consistency group '$Name' was not found."
}

function Resolve-DMHyperMetroConsistencyGroupId {
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        return $Id
    }

    $matches = @(Get-DMHyperMetroConsistencyGroup -WebSession $WebSession -Name $Name)
    if ($matches.Count -eq 1) {
        return $matches[0].Id
    }
    if ($matches.Count -gt 1) {
        throw "HyperMetro consistency group name '$Name' is ambiguous."
    }
    throw "HyperMetro consistency group '$Name' was not found."
}

function Resolve-DMVStorePairId {
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$LocalVStoreName,
        [string]$RemoteVStoreName,
        [string]$ReplicationType
    )

    if ($Id) {
        return $Id
    }

    $matches = @(Get-DMVStorePair -WebSession $WebSession -ReplicationType $ReplicationType | Where-Object {
            $_.'Local vStore Name' -eq $LocalVStoreName -and $_.'Remote vStore Name' -eq $RemoteVStoreName
        })
    if ($matches.Count -eq 1) {
        return $matches[0].Id
    }
    if ($matches.Count -gt 1) {
        throw "vStore pair '$LocalVStoreName' -> '$RemoteVStoreName' is ambiguous."
    }
    throw "vStore pair '$LocalVStoreName' -> '$RemoteVStoreName' was not found."
}

function Resolve-DMFileHyperMetroDomainId {
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        return $Id
    }

    $matches = @(Get-DMFileHyperMetroDomain -WebSession $WebSession -Name $Name)
    if ($matches.Count -eq 1) {
        return $matches[0].Id
    }
    if ($matches.Count -gt 1) {
        throw "File HyperMetro domain name '$Name' is ambiguous."
    }
    throw "File HyperMetro domain '$Name' was not found."
}

function Add-DMOptionalBodyValue {
    param(
        [hashtable]$Body,
        [string]$Key,
        [object]$Value,
        [bool]$IsPresent
    )

    if ($IsPresent) {
        $Body[$Key] = $Value
    }
}
