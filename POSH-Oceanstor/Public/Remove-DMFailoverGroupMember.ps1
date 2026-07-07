function Remove-DMFailoverGroupMember {
    <#
    .SYNOPSIS
        Removes a port member from an OceanStor failover group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $resource = "failovergroup/associate?ID=$([uri]::EscapeDataString($Id))&ASSOCIATEOBJTYPE=$AssociateObjectType&ASSOCIATEOBJID=$([uri]::EscapeDataString($AssociateObjectId))"

            if ($PSCmdlet.ShouldProcess("$AssociateObjectId <- $Id", 'Remove failover group member')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}

Set-Alias -Name Delete-DMFailoverGroupMember -Value Remove-DMFailoverGroupMember
