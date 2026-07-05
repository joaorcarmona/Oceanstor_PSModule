function Set-DMReplicationConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$')][string]$NewName,
        [ValidateLength(0, 127)][string]$Description,
        [ValidateSet('Manual', 'TimedWaitAfterStart', 'TimedWaitAfterSync', 'SpecificTimePolicy')][string]$SynchronizationType,
        [ValidateSet('Automatic', 'Manual')][string]$RecoveryPolicy,
        [ValidateSet('Low', 'Medium', 'High', 'Highest')][string]$Speed,
        [int]$TimingValue,
        [int]$TimingValueInSeconds,
        [hashtable]$ApiProperties
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupId = Resolve-DMReplicationConsistencyGroupId -WebSession $session -Id $Id -Name $Name
    $body = @{ ID = $groupId }
    Add-DMOptionalBodyValue -Body $body -Key 'NAME' -Value $NewName -IsPresent $PSBoundParameters.ContainsKey('NewName')
    Add-DMOptionalBodyValue -Body $body -Key 'DESCRIPTION' -Value $Description -IsPresent $PSBoundParameters.ContainsKey('Description')
    if ($SynchronizationType) { $body.SYNCHRONIZETYPE = ConvertTo-DMReplicationSynchronizationTypeCode $SynchronizationType }
    if ($RecoveryPolicy) { $body.RECOVERYPOLICY = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy }
    if ($Speed) { $body.SPEED = ConvertTo-DMDrSpeedCode $Speed }
    Add-DMOptionalBodyValue -Body $body -Key 'TIMINGVAL' -Value $TimingValue -IsPresent $PSBoundParameters.ContainsKey('TimingValue')
    Add-DMOptionalBodyValue -Body $body -Key 'TIMINGVALINSEC' -Value $TimingValueInSeconds -IsPresent $PSBoundParameters.ContainsKey('TimingValueInSeconds')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }
    if ($body.Count -le 1) { throw 'Specify at least one remote replication consistency group property to modify.' }
    if ($PSCmdlet.ShouldProcess($groupId, 'Modify remote replication consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "CONSISTENTGROUP/$groupId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
