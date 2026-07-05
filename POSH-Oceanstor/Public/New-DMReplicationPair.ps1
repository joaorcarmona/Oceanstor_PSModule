function New-DMReplicationPair {
    <#
    .SYNOPSIS
        Creates an OceanStor remote replication pair.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ById')]
    [OutputType([OceanstorReplicationPair])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LocalLunId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LocalLunName,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteDeviceId,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteLunId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteLunName,

        [ValidateSet('Manual', 'TimedWaitAfterStart', 'TimedWaitAfterSync', 'SpecificTimePolicy')]
        [string]$SynchronizationType = 'Manual',

        [ValidateSet('Sync', 'Async')]
        [string]$ReplicationMode = 'Async',

        [ValidateSet('Automatic', 'Manual')]
        [string]$RecoveryPolicy = 'Automatic',

        [ValidateSet('Low', 'Medium', 'High', 'Highest')]
        [string]$Speed = 'Medium',

        [ValidateRange(3, 86400)]
        [int]$TimingValue,

        [ValidateSet('AllData', 'WrittenData')]
        [string]$InitialSyncType,

        [hashtable]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    $resolvedLocalLunId = if ($LocalLunName) {
        $lun = @(Get-DMlun -WebSession $session -Name $LocalLunName | Where-Object Name -EQ $LocalLunName)[0]
        if ($null -eq $lun) { throw "Local LUN '$LocalLunName' was not found." }
        $lun.Id
    }
    else {
        $LocalLunId
    }

    $resolvedRemoteLunId = if ($RemoteLunName) {
        $remoteLun = @(Get-DMRemoteLun -WebSession $session -RemoteDeviceId $RemoteDeviceId -Name $RemoteLunName | Where-Object Name -EQ $RemoteLunName)[0]
        if ($null -eq $remoteLun) { throw "Remote LUN '$RemoteLunName' was not found on remote device '$RemoteDeviceId'." }
        $remoteLun.'Remote Lun Id'
    }
    else {
        $RemoteLunId
    }

    $body = @{
        LOCALRESID       = $resolvedLocalLunId
        LOCALRESTYPE     = 11
        REMOTEDEVICEID   = $RemoteDeviceId
        REMOTERESID      = $resolvedRemoteLunId
        SYNCHRONIZETYPE  = ConvertTo-DMReplicationSynchronizationTypeCode $SynchronizationType
        RECOVERYPOLICY   = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy
        SPEED            = ConvertTo-DMDrSpeedCode $Speed
        REPLICATIONMODEL = ConvertTo-DMReplicationModeCode $ReplicationMode
    }
    Add-DMOptionalBodyValue -Body $body -Key 'TIMINGVAL' -Value $TimingValue -IsPresent $PSBoundParameters.ContainsKey('TimingValue')
    if ($InitialSyncType) {
        $body.initialSyncType = if ($InitialSyncType -eq 'AllData') { '1' } else { '2' }
    }
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }

    if ($PSCmdlet.ShouldProcess("$resolvedLocalLunId -> $resolvedRemoteLunId", 'Create remote replication pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'REPLICATIONPAIR' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorReplicationPair]::new($response.data, $session)
        }
        return $response.error
    }
}
