function Rename-DMLun {
    <#
    .SYNOPSIS
        Renames an OceanStor Dorado V6 LUN through Set-DMLun.
    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMLun.
    .EXAMPLE
        PS> Rename-DMLun -LunName 'database' -NewName 'database-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$LunName,
        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName
    )

    if ($PSCmdlet.ShouldProcess($LunName, "Rename LUN to '$NewName'")) {
        return Set-DMLun -WebSession $WebSession -LunName $LunName -NewName $NewName -Confirm:$false
    }
}
