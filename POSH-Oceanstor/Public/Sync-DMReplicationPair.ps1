function Sync-DMReplicationPair {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [switch]$FullCopy
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMReplicationPairId -WebSession $session -Id $Id -Name $Name
    $body = @{ ID = $pairId }
    if ($PSBoundParameters.ContainsKey('FullCopy')) { $body.isFullCopy = [bool]$FullCopy }
    if ($PSCmdlet.ShouldProcess($pairId, 'Synchronize remote replication pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'REPLICATIONPAIR/sync' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
