function Rename-DMHost {
    <#
    .SYNOPSIS
        Renames an OceanStor host through Set-DMHost.

    .DESCRIPTION
        Renames an OceanStor host by resolving the current name and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

        Accepts multiple hosts from the pipeline by property name. Each is forwarded to Set-DMHost
        independently, so a failure renaming one does not stop the rest. Renaming a batch of more than
        one host to the same NewName is not meaningful.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER HostName
        Current name of the host to rename.

    .PARAMETER NewName
        New name to assign to the host.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMHost.
    .EXAMPLE
        PS> Rename-DMHost -HostName 'esx01' -NewName 'esx01-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$HostName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    process {
        if ($PSCmdlet.ShouldProcess($HostName, "Rename host to '$NewName'")) {
            return Set-DMHost -WebSession $WebSession -HostName $HostName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
        }
    }
}
