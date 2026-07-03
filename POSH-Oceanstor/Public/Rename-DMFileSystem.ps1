function Rename-DMFileSystem {
    <#
    .SYNOPSIS
        Renames an OceanStor file system through Set-DMFileSystem.

    .DESCRIPTION
        Renames an OceanStor file system by resolving the current name and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

        Accepts multiple file systems from the pipeline by property name. Each is forwarded to
        Set-DMFileSystem independently, so a failure renaming one does not stop the rest. Renaming a
        batch of more than one file system to the same NewName is not meaningful.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER FileSystemName
        Current name of the file system to rename.

    .PARAMETER NewName
        New name to assign to the file system.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMFileSystem.
    .EXAMPLE
        PS> Rename-DMFileSystem -FileSystemName 'documents' -NewName 'documents-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$FileSystemName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName
    )

    process {
        if ($PSCmdlet.ShouldProcess($FileSystemName, "Rename file system to '$NewName'")) {
            return Set-DMFileSystem -WebSession $WebSession -FileSystemName $FileSystemName -NewName $NewName -Confirm:$false
        }
    }
}
