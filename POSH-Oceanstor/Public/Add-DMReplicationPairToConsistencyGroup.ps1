function Add-DMReplicationPairToConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)][string]$GroupId,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$GroupName,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)][Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$PairId
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupIdValue = Resolve-DMReplicationConsistencyGroupId -WebSession $session -Id $GroupId -Name $GroupName
    $body = @{ ID = $groupIdValue; RMLIST = @($PairId) }
    if ($PSCmdlet.ShouldProcess($PairId, "Add to remote replication consistency group $groupIdValue")) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'ADD_MIRROR' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
