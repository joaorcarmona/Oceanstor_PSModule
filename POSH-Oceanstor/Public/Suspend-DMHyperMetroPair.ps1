function Suspend-DMHyperMetroPair {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [bool]$IsPrimary = $false
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMHyperMetroPairId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($pairId, 'Suspend HyperMetro pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'HyperMetroPair/disable_hcpair' -BodyData @{ ID = $pairId; ISPRIMARY = $IsPrimary }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
