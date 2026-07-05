function Join-DMFileHyperMetroDomain {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param([Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession, [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id, [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name)
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $domainId = Resolve-DMFileHyperMetroDomainId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($domainId, 'Join file-system HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'JoinFsHyperMetroDomain' -BodyData @{ ID = $domainId }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
