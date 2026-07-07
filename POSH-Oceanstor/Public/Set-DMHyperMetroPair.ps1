function Set-DMHyperMetroPair {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [ValidateSet('Automatic', 'Manual')][string]$RecoveryPolicy,
        [ValidateSet('Low', 'Medium', 'High', 'Highest')][string]$Speed,
        [bool]$Isolation,
        [ValidateRange(10, 30000)][int]$IsolationThresholdTime,
        [hashtable]$ApiProperties
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMHyperMetroPairId -WebSession $session -Id $Id -Name $Name
    $body = @{ ID = $pairId }
    if ($RecoveryPolicy) { $body.RECOVERYPOLICY = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy }
    if ($Speed) { $body.SPEED = ConvertTo-DMDrSpeedCode $Speed }
    Add-DMOptionalBodyValue -Body $body -Key 'isIsolation' -Value $Isolation -IsPresent $PSBoundParameters.ContainsKey('Isolation')
    Add-DMOptionalBodyValue -Body $body -Key 'isolationThresholdTime' -Value $IsolationThresholdTime -IsPresent $PSBoundParameters.ContainsKey('IsolationThresholdTime')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }
    if ($body.Count -le 1) { throw 'Specify at least one HyperMetro pair property to modify.' }
    if ($PSCmdlet.ShouldProcess($pairId, 'Modify HyperMetro pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "HyperMetroPair/$pairId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
