function Enable-DMReplicationPairSecondaryProtection {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMReplicationPairId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($pairId, 'Enable secondary resource protection')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "REPLICATIONPAIR/$pairId" -BodyData @{ ID = $pairId; SECRESACCESS = '2' }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
