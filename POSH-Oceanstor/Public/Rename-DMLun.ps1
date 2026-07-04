function Rename-DMLun {
    <#
    .SYNOPSIS
        Renames an OceanStor Dorado V6 LUN through Set-DMLun.

    .DESCRIPTION
        Renames an OceanStor LUN by resolving the current name or ID and issuing a PUT with the new name.
        Validates that the new name does not conflict with an existing object.

        Accepts multiple LUNs from the pipeline by property name. Each LUN is forwarded to Set-DMLun
        independently, so a failure renaming one LUN (e.g. a name collision) is reported as a
        non-terminating error and does not stop the rest from being processed. Renaming a batch of more
        than one LUN to the same NewName is not meaningful -- only the first will succeed, since every
        LUN after it collides on the now-taken name.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default. When a LUN object piped from Get-DMlun carries its own session, that session is used instead.

    .PARAMETER LunName
        Current name of the LUN to rename. Accepts pipeline input by property name (a piped object's Name property).

    .PARAMETER LunId
        Current ID of the LUN to rename. Using LunId avoids a name lookup and is the fastest path.

    .PARAMETER NewName
        New name to assign to the LUN.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMLun.
    .EXAMPLE
        PS> Rename-DMLun -LunName 'database' -NewName 'database-prod'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$LunName,
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()][string]$LunId,
        [Parameter(Mandatory, Position = 1)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName
    )

    process {
        $target = if ($LunName) { $LunName } else { $LunId }
        if ($PSCmdlet.ShouldProcess($target, "Rename LUN to '$NewName'")) {
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                return Set-DMLun -WebSession $WebSession -LunId $LunId -NewName $NewName -Confirm:$false
            }
            return Set-DMLun -WebSession $WebSession -LunName $LunName -NewName $NewName -Confirm:$false
        }
    }
}
