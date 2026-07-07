function New-DMFileSystemReplicationPair {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType('OceanstorReplicationPair')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$LocalFileSystemId,
        [Parameter(Mandatory = $true)][string]$RemoteDeviceId,
        [Parameter(Mandatory = $true)][string]$RemoteFileSystemId,
        [ValidateSet('Manual', 'TimedWaitAfterStart', 'TimedWaitAfterSync', 'SpecificTimePolicy')]
        [string]$SynchronizationType = 'Manual',
        [ValidateSet('Sync', 'Async')][string]$ReplicationMode = 'Async',
        [ValidateSet('Automatic', 'Manual')][string]$RecoveryPolicy = 'Automatic',
        [ValidateSet('Low', 'Medium', 'High', 'Highest')][string]$Speed = 'Medium',
        [string]$VStorePairId,
        [string]$VstoreId,
        [int]$TimingValue,
        [hashtable]$ApiProperties
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{
        LOCALRESID       = $LocalFileSystemId
        LOCALRESTYPE     = 40
        REMOTEDEVICEID   = $RemoteDeviceId
        REMOTERESID      = $RemoteFileSystemId
        SYNCHRONIZETYPE  = ConvertTo-DMReplicationSynchronizationTypeCode $SynchronizationType
        RECOVERYPOLICY   = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy
        SPEED            = ConvertTo-DMDrSpeedCode $Speed
        REPLICATIONMODEL = ConvertTo-DMReplicationModeCode $ReplicationMode
    }
    Add-DMOptionalBodyValue -Body $body -Key 'VSTOREPAIRID' -Value $VStorePairId -IsPresent $PSBoundParameters.ContainsKey('VStorePairId')
    Add-DMOptionalBodyValue -Body $body -Key 'vstoreId' -Value $VstoreId -IsPresent $PSBoundParameters.ContainsKey('VstoreId')
    Add-DMOptionalBodyValue -Body $body -Key 'TIMINGVAL' -Value $TimingValue -IsPresent $PSBoundParameters.ContainsKey('TimingValue')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }
    if ($PSCmdlet.ShouldProcess("$LocalFileSystemId -> $RemoteFileSystemId", 'Create file-system remote replication pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'REPLICATIONPAIR' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorReplicationPair]::new($response.data, $session)
        }
        return $response.error
    }
}
