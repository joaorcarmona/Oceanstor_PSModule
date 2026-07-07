function Remove-DMHyperMetroDomain {
    <#
    .SYNOPSIS
        Removes an OceanStor SAN HyperMetro domain.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [bool]$LocalDelete = $false
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $domainId = Resolve-DMHyperMetroDomainId -WebSession $session -Id $Id -Name $Name
    $resource = "HyperMetroDomain/$domainId" + "?ISLOCALDELETE=$($LocalDelete.ToString().ToLowerInvariant())"

    if ($PSCmdlet.ShouldProcess($domainId, 'Remove SAN HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
