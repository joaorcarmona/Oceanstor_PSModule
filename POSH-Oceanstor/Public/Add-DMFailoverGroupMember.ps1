function Add-DMFailoverGroupMember {
    <#
    .SYNOPSIS
        Adds a port member to an OceanStor failover group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet(213, 235, 280)]
        [int]$AssociateObjectType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AssociateObjectId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{
        ID               = $Id
        ASSOCIATEOBJTYPE = $AssociateObjectType
        ASSOCIATEOBJID   = $AssociateObjectId
    }

    if ($PSCmdlet.ShouldProcess("$AssociateObjectId -> $Id", 'Add failover group member')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'failovergroup/associate' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
