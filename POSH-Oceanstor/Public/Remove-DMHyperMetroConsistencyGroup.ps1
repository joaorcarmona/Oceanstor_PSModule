function Remove-DMHyperMetroConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupId = Resolve-DMHyperMetroConsistencyGroupId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($groupId, 'Remove HyperMetro consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "HyperMetro_ConsistentGroup/$groupId"
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
