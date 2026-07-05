function Remove-DMVStorePair {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByNames', Mandatory = $true)][string]$LocalVStoreName,
        [Parameter(ParameterSetName = 'ByNames', Mandatory = $true)][string]$RemoteVStoreName,
        [Parameter(ParameterSetName = 'ByNames')][ValidateSet('HyperMetro', 'RemoteReplication')][string]$ReplicationType,
        [bool]$LocalDelete = $false
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMVStorePairId -WebSession $session -Id $Id -LocalVStoreName $LocalVStoreName -RemoteVStoreName $RemoteVStoreName -ReplicationType $ReplicationType
    $resource = "vstore_pair/$pairId" + "?ISLOCALDELETEDONLY=$($LocalDelete.ToString().ToLowerInvariant())"
    if ($PSCmdlet.ShouldProcess($pairId, 'Remove vStore pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
