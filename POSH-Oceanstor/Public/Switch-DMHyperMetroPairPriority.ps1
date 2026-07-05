function Switch-DMHyperMetroPairPriority {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMHyperMetroPairId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($pairId, 'Switch HyperMetro pair priority')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'HyperMetroPair/SWAP_HCPAIR' -BodyData @{ ID = $pairId; HCRESOURCETYPE = '1' }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
