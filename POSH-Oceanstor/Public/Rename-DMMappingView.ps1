function Rename-DMMappingView {
    <#
    .SYNOPSIS
        Renames an OceanStor mapping view through Set-DMMappingView.

    .DESCRIPTION
        Renames an OceanStor mapping view by resolving the current name and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

        Accepts multiple mapping views from the pipeline by property name. Each is forwarded to
        Set-DMMappingView independently, so a failure renaming one does not stop the rest. Renaming a
        batch of more than one mapping view to the same NewName is not meaningful.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER MappingViewName
        Current name of the mapping view to rename.

    .PARAMETER NewName
        New name to assign to the mapping view.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMMappingView.
    .EXAMPLE
        PS> Rename-DMMappingView -MappingViewName 'db-view' -NewName 'db-view-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$MappingViewName,
        [Parameter(Mandatory, Position = 1)]
        [ValidateLength(1, 31)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    process {
        if ($PSCmdlet.ShouldProcess($MappingViewName, "Rename mapping view to '$NewName'")) {
            return Set-DMMappingView -WebSession $WebSession -MappingViewName $MappingViewName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
        }
    }
}
