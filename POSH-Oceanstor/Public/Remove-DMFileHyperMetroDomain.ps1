function Remove-DMFileHyperMetroDomain {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [bool]$LocalDelete = $false,
        [bool]$ForceDelete = $false
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $domainId = Resolve-DMFileHyperMetroDomainId -WebSession $session -Id $Id -Name $Name
    $resource = "FsHyperMetroDomain/$domainId" + "?ISLOCALDELETE=$($LocalDelete.ToString().ToLowerInvariant())&ISFORCEDELETE=$($ForceDelete.ToString().ToLowerInvariant())"
    if ($PSCmdlet.ShouldProcess($domainId, 'Remove file-system HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
