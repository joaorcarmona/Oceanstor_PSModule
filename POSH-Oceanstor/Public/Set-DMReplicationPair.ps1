function Set-DMReplicationPair {
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

        [ValidateSet('Manual', 'TimedWaitAfterStart', 'TimedWaitAfterSync', 'SpecificTimePolicy')]
        [string]$SynchronizationType,

        [ValidateSet('Sync', 'Async')]
        [string]$ReplicationMode,

        [ValidateSet('Automatic', 'Manual')]
        [string]$RecoveryPolicy,

        [ValidateSet('Low', 'Medium', 'High', 'Highest')]
        [string]$Speed,

        [hashtable]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMReplicationPairId -WebSession $session -Id $Id -Name $Name
    $body = @{ ID = $pairId }
    if ($SynchronizationType) { $body.SYNCHRONIZETYPE = ConvertTo-DMReplicationSynchronizationTypeCode $SynchronizationType }
    if ($ReplicationMode) { $body.REPLICATIONMODEL = ConvertTo-DMReplicationModeCode $ReplicationMode }
    if ($RecoveryPolicy) { $body.RECOVERYPOLICY = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy }
    if ($Speed) { $body.SPEED = ConvertTo-DMDrSpeedCode $Speed }
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }

    if ($body.Count -le 1) {
        throw 'Specify at least one replication pair property to modify.'
    }

    if ($PSCmdlet.ShouldProcess($pairId, 'Modify remote replication pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "REPLICATIONPAIR/$pairId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
