function Suspend-DMHyperMetroConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [ValidateSet('Preferred', 'NonPreferred')]
        [string]$PriorityStationType = 'NonPreferred'
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $groupId = Resolve-DMHyperMetroConsistencyGroupId -WebSession $session -Id $Id -Name $Name
    $body = @{
        ID                  = $groupId
        PRIORITYSTATIONTYPE = if ($PriorityStationType -eq 'Preferred') { '0' } else { '1' }
    }
    if ($PSCmdlet.ShouldProcess($groupId, 'Suspend HyperMetro consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'HyperMetro_ConsistentGroup/stop' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
