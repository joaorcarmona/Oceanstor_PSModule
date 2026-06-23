function Rename-DMPortGroup {
    <#
    .SYNOPSIS
        Renames an OceanStor port group through Set-DMPortGroup.

    .DESCRIPTION
        Renames an OceanStor port group by resolving the current name and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The global deviceManager session is used by default.

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
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$PortGroupName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    if ($PSCmdlet.ShouldProcess($PortGroupName, "Rename port group to '$NewName'")) {
        return Set-DMPortGroup -WebSession $WebSession -PortGroupName $PortGroupName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
    }
}
