function Remove-DMHyperMetroPairFromConsistencyGroup {
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
    $resource = 'hyperMetro/associate/pair?ID={0}&ASSOCIATEOBJID={1}' -f [uri]::EscapeDataString($groupIdValue), [uri]::EscapeDataString($PairId)
    if ($PSCmdlet.ShouldProcess($PairId, "Remove from HyperMetro consistency group $groupIdValue")) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
