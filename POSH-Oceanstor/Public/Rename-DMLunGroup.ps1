function Rename-DMLunGroup {
    <#
    .SYNOPSIS
        Renames an OceanStor LUN group through Set-DMLunGroup.

    .DESCRIPTION
        Renames an OceanStor LUN group by resolving the current name and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

        Accepts multiple LUN groups from the pipeline by property name. Each is forwarded to
        Set-DMLunGroup independently, so a failure renaming one does not stop the rest. Renaming a
        batch of more than one LUN group to the same NewName is not meaningful.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER LunGroupName
        Current name of the LUN group to rename.

    .PARAMETER NewName
        New name to assign to the LUN group.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMLunGroup.
    .EXAMPLE
        PS> Rename-DMLunGroup -LunGroupName 'databases' -NewName 'databases-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$LunGroupName,
        [Parameter(Mandatory, Position = 1)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    process {
        if ($PSCmdlet.ShouldProcess($LunGroupName, "Rename LUN group to '$NewName'")) {
            return Set-DMLunGroup -WebSession $WebSession -LunGroupName $LunGroupName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
        }
    }
}
