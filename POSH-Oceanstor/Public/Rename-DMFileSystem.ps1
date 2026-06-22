function Rename-DMFileSystem {
    <#
    .SYNOPSIS
        Renames an OceanStor file system through Set-DMFileSystem.
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
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$FileSystemName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName
    )

    if ($PSCmdlet.ShouldProcess($FileSystemName, "Rename file system to '$NewName'")) {
        return Set-DMFileSystem -WebSession $WebSession -FileSystemName $FileSystemName -NewName $NewName -Confirm:$false
    }
}
