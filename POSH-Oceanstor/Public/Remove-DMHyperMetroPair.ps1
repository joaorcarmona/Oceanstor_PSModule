function Remove-DMHyperMetroPair {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id,
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)][string]$Name,
        [bool]$LocalDelete = $false,
        [bool]$RefreshWwn = $true
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMHyperMetroPairId -WebSession $session -Id $Id -Name $Name
    $resource = "HyperMetroPair/$pairId" + "?ISLOCALDELETE=$($LocalDelete.ToString().ToLowerInvariant())&ISREFRESHWWN=$($RefreshWwn.ToString().ToLowerInvariant())"
    if ($PSCmdlet.ShouldProcess($pairId, 'Remove HyperMetro pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
