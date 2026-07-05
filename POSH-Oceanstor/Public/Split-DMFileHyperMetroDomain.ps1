function Split-DMFileHyperMetroDomain {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [ValidateSet('Preferred', 'NonPreferred')][string]$StopRole
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $domainId = Resolve-DMFileHyperMetroDomainId -WebSession $session -Id $Id -Name $Name
    $body = @{ ID = $domainId }
    if ($StopRole) { $body.STOPROLE = if ($StopRole -eq 'Preferred') { '0' } else { '1' } }
    if ($PSCmdlet.ShouldProcess($domainId, 'Split file-system HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'SplitFsHyperMetroDomain' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
