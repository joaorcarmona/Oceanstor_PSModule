function Switch-DMHyperMetroConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupId = Resolve-DMHyperMetroConsistencyGroupId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($groupId, 'Switch HyperMetro consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'HyperMetro_ConsistentGroup/switch' -BodyData @{ ID = $groupId }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
