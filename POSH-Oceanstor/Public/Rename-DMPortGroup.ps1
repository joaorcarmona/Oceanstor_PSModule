function Rename-DMPortGroup {
    <#
    .SYNOPSIS
        Renames an OceanStor port group through Set-DMPortGroup.

    .DESCRIPTION
        Renames an OceanStor port group by resolving the current name and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

        Accepts multiple port groups from the pipeline by property name. Each is forwarded to
        Set-DMPortGroup independently, so a failure renaming one does not stop the rest. Renaming a
        batch of more than one port group to the same NewName is not meaningful.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER PortGroupName
        Current name of the port group to rename.

    .PARAMETER NewName
        New name to assign to the port group.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMPortGroup.
    .EXAMPLE
        PS> Rename-DMPortGroup -PortGroupName 'front-end' -NewName 'front-end-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$PortGroupName,
        [Parameter(Mandatory, Position = 1)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    process {
        if ($PSCmdlet.ShouldProcess($PortGroupName, "Rename port group to '$NewName'")) {
            return Set-DMPortGroup -WebSession $WebSession -PortGroupName $PortGroupName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
        }
    }
}
