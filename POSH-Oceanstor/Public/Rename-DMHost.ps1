function Rename-DMHost {
    <#
    .SYNOPSIS
        Renames an OceanStor host through Set-DMHost.
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
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$HostName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    if ($PSCmdlet.ShouldProcess($HostName, "Rename host to '$NewName'")) {
        return Set-DMHost -WebSession $WebSession -HostName $HostName -NewName $NewName -VstoreId $VstoreId -Confirm:$false
    }
}
