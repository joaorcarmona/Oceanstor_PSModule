function New-DMReplicationConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([OceanstorReplicationConsistencyGroup])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$')]
        [string]$Name,

        [ValidateLength(0, 127)]
        [string]$Description,

        [ValidateSet('Manual', 'TimedWaitAfterStart', 'TimedWaitAfterSync', 'SpecificTimePolicy')]
        [string]$SynchronizationType = 'Manual',

        [ValidateSet('Sync', 'Async')]
        [string]$ReplicationMode = 'Async',

        [ValidateSet('Automatic', 'Manual')]
        [string]$RecoveryPolicy = 'Automatic',

        [ValidateSet('Low', 'Medium', 'High', 'Highest')]
        [string]$Speed = 'Medium',

        [string]$RemoteDeviceId,
        [string]$LocalProtectionGroupId,
        [string]$RemoteProtectionGroupId,
        [int]$TimingValue,
        [int]$TimingValueInSeconds,
        [hashtable]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{
        NAME             = $Name
        LOCALRESTYPE     = 11
        SYNCHRONIZETYPE  = ConvertTo-DMReplicationSynchronizationTypeCode $SynchronizationType
        REPLICATIONMODEL = ConvertTo-DMReplicationModeCode $ReplicationMode
        RECOVERYPOLICY   = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy
        SPEED            = ConvertTo-DMDrSpeedCode $Speed
    }
    Add-DMOptionalBodyValue -Body $body -Key 'DESCRIPTION' -Value $Description -IsPresent $PSBoundParameters.ContainsKey('Description')
    Add-DMOptionalBodyValue -Body $body -Key 'remoteArrayID' -Value $RemoteDeviceId -IsPresent $PSBoundParameters.ContainsKey('RemoteDeviceId')
    Add-DMOptionalBodyValue -Body $body -Key 'localpgId' -Value $LocalProtectionGroupId -IsPresent $PSBoundParameters.ContainsKey('LocalProtectionGroupId')
    Add-DMOptionalBodyValue -Body $body -Key 'rmtpgId' -Value $RemoteProtectionGroupId -IsPresent $PSBoundParameters.ContainsKey('RemoteProtectionGroupId')
    Add-DMOptionalBodyValue -Body $body -Key 'TIMINGVAL' -Value $TimingValue -IsPresent $PSBoundParameters.ContainsKey('TimingValue')
    Add-DMOptionalBodyValue -Body $body -Key 'TIMINGVALINSEC' -Value $TimingValueInSeconds -IsPresent $PSBoundParameters.ContainsKey('TimingValueInSeconds')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create remote replication consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'CONSISTENTGROUP' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorReplicationConsistencyGroup]::new($response.data, $session)
        }
        return $response.error
    }
}
