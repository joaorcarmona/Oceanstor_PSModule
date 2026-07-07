function Add-DMHyperMetroPairToConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)][string]$GroupId,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$GroupName,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)][Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$PairId
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupIdValue = Resolve-DMHyperMetroConsistencyGroupId -WebSession $session -Id $GroupId -Name $GroupName
    $body = @{ ID = $groupIdValue; ASSOCIATEOBJID = $PairId }
    if ($PSCmdlet.ShouldProcess($PairId, "Add to HyperMetro consistency group $groupIdValue")) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'hyperMetro/associate/pair' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
