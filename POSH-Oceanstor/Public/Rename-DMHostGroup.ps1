function Rename-DMHostGroup {
    <#
    .SYNOPSIS
        Renames an OceanStor host group through Set-DMHostGroup.

    .DESCRIPTION
        Renames an OceanStor host group by resolving the current name and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER HostGroupName
        Current name of the host group to rename.

    .PARAMETER NewName
        New name to assign to the host group.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMHostGroup.
    .EXAMPLE
        PS> Rename-DMHostGroup -HostGroupName 'cluster' -NewName 'cluster-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$HostGroupName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    if ($PSCmdlet.ShouldProcess($HostGroupName, "Rename host group to '$NewName'")) {
        return Set-DMHostGroup -WebSession $WebSession -HostGroupName $HostGroupName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
    }
}
