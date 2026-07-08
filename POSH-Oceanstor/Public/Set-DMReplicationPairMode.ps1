function Set-DMReplicationPairMode {
    <#
    .SYNOPSIS
        Changes the replication mode of an OceanStor remote replication pair.

    .DESCRIPTION
        Dedicated wrapper for the documented REPLICATIONPAIR/transfer endpoint
        (OceanStor Dorado 6.1.6 REST Interface Reference, 4.9.2.3.1 "Interface for
        Changing the Replication Mode of a Remote Replication Pair"). Switching a
        pair between synchronous and asynchronous replication is a DR-state change,
        so this is treated as a High-impact mutator with SupportsShouldProcess.

        Prefer this wrapper over passing REPLICATIONMODEL through Set-DMReplicationPair
        -ApiProperties: the transfer endpoint is a distinct operation from the
        in-place REPLICATIONPAIR/{id} modify used by Set-DMReplicationPair.

    .PARAMETER ReplicationMode
        Target replication mode: Sync (synchronous) or Async (asynchronous).

    .PARAMETER SynchronizationType
        Synchronization type. The REST reference marks this mandatory when the mode
        is changed to asynchronous replication, so it is required when ReplicationMode
        is Async.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Sync', 'Async')]
        [string]$ReplicationMode,

        [ValidateSet('Manual', 'TimedWaitAfterStart', 'TimedWaitAfterSync', 'SpecificTimePolicy')]
        [string]$SynchronizationType
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    if ($ReplicationMode -eq 'Async' -and -not $SynchronizationType) {
        throw 'SynchronizationType is required when changing a replication pair to asynchronous replication.'
    }

    $pairId = Resolve-DMReplicationPairId -WebSession $session -Id $Id -Name $Name

    # TYPE 263 = remote replication pair (per REST reference transfer parameters).
    $body = @{
        ID             = $pairId
        TYPE           = 263
        REPLICATIONMODEL = ConvertTo-DMReplicationModeCode $ReplicationMode
    }
    if ($SynchronizationType) {
        $body.SYNCHRONIZETYPE = ConvertTo-DMReplicationSynchronizationTypeCode $SynchronizationType
    }

    if ($PSCmdlet.ShouldProcess($pairId, "Change remote replication pair mode to $ReplicationMode")) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'REPLICATIONPAIR/transfer' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
