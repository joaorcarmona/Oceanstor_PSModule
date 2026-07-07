function Add-DMQuorumServerToHyperMetroDomain {
    <#
    .SYNOPSIS
        Adds a quorum server to an OceanStor SAN HyperMetro domain.
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

    if ($PSCmdlet.ShouldProcess($domainId, 'Add quorum server to SAN HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'HyperMetroDomain/CREATE_ASSOCIATE' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
