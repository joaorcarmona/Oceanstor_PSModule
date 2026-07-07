function Set-DMHyperMetroConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$')][string]$NewName,
        [ValidateLength(0, 127)][string]$Description,
        [ValidateSet('Automatic', 'Manual')][string]$RecoveryPolicy,
        [ValidateSet('Low', 'Medium', 'High', 'Highest')][string]$Speed,
        [bool]$Isolation,
        [ValidateRange(10, 30000)][int]$IsolationThresholdTime,
        [ValidateRange(1, 1024)][int]$Bandwidth,
        [hashtable]$ApiProperties
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupId = Resolve-DMHyperMetroConsistencyGroupId -WebSession $session -Id $Id -Name $Name
    $body = @{ ID = $groupId }
    Add-DMOptionalBodyValue -Body $body -Key 'NAME' -Value $NewName -IsPresent $PSBoundParameters.ContainsKey('NewName')
    Add-DMOptionalBodyValue -Body $body -Key 'DESCRIPTION' -Value $Description -IsPresent $PSBoundParameters.ContainsKey('Description')
    if ($RecoveryPolicy) { $body.RECOVERYPOLICY = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy }
    if ($Speed) { $body.SPEED = ConvertTo-DMDrSpeedCode $Speed }
    Add-DMOptionalBodyValue -Body $body -Key 'ISISOLATION' -Value $Isolation -IsPresent $PSBoundParameters.ContainsKey('Isolation')
    Add-DMOptionalBodyValue -Body $body -Key 'ISISOLATIONTHRESHOLDTIME' -Value $IsolationThresholdTime -IsPresent $PSBoundParameters.ContainsKey('IsolationThresholdTime')
    Add-DMOptionalBodyValue -Body $body -Key 'bandwidth' -Value $Bandwidth -IsPresent $PSBoundParameters.ContainsKey('Bandwidth')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }
    if ($body.Count -le 1) { throw 'Specify at least one HyperMetro consistency group property to modify.' }
    if ($PSCmdlet.ShouldProcess($groupId, 'Modify HyperMetro consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "HyperMetro_ConsistentGroup/$groupId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
