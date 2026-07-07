function Start-DMFileHyperMetroDomain {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param([Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession, [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id, [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name)
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $domainId = Resolve-DMFileHyperMetroDomainId -WebSession $session -Id $Id -Name $Name
    if ($PSCmdlet.ShouldProcess($domainId, 'Start file-system HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'StartFsHyperMetroDomain' -BodyData @{ ID = $domainId }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
