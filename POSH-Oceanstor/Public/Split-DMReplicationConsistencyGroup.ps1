function Split-DMReplicationConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupId = Resolve-DMReplicationConsistencyGroupId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($groupId, 'Split remote replication consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'SPLIT_CONSISTENCY_GROUP' -BodyData @{ ID = $groupId }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
