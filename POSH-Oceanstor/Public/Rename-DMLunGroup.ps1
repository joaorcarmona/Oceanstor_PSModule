function Rename-DMLunGroup {
    <#
    .SYNOPSIS
        Renames an OceanStor LUN group through Set-DMLunGroup.
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
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$LunGroupName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    if ($PSCmdlet.ShouldProcess($LunGroupName, "Rename LUN group to '$NewName'")) {
        return Set-DMLunGroup -WebSession $WebSession -LunGroupName $LunGroupName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
    }
}
