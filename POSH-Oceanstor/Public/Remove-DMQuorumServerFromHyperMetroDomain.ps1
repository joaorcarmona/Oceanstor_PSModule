function Remove-DMQuorumServerFromHyperMetroDomain {
    <#
    .SYNOPSIS
        Removes a quorum server from an OceanStor SAN HyperMetro domain.
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

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$QuorumServerId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $domainId = Resolve-DMHyperMetroDomainId -WebSession $session -Id $Id -Name $Name
    $body = @{
        ID             = $domainId
        ASSOCIATEOBJID = $QuorumServerId
    }

    if ($PSCmdlet.ShouldProcess($domainId, 'Remove quorum server from SAN HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'HyperMetroDomain/REMOVE_ASSOCIATE' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
