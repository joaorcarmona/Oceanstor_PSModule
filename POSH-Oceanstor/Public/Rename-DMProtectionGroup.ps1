function Rename-DMProtectionGroup {
    <#
    .SYNOPSIS
        Renames an OceanStor protection group through Set-DMProtectionGroup.

    .DESCRIPTION
        Renames an OceanStor protection group by resolving the current Name or Id and issuing a PUT
        with the new name. Validates that the new name does not conflict with an existing object.

        Accepts multiple protection groups from the pipeline by property name. Each is forwarded to
        Set-DMProtectionGroup independently, so a failure renaming one does not stop the rest.
        Renaming a batch of more than one protection group to the same NewName is not meaningful.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER Name
        Current name of the protection group to rename. Supports tab completion. Mutually exclusive with Id.

    .PARAMETER Id
        Current Id of the protection group to rename. Validated against existing protection groups, no tab completion. Mutually exclusive with Name.

    .PARAMETER NewName
        New name to assign to the protection group.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession, or a protection group object (from Get-DMProtectionGroup) by property name.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object from Set-DMProtectionGroup.
    .EXAMPLE
        PS> Rename-DMProtectionGroup -Name 'pg-old' -NewName 'pg-new'
    .EXAMPLE
        PS> Rename-DMProtectionGroup -Id 5 -NewName 'pg-new'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMProtectionGroup -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid Id.'
            })]
        [string]$Id,

        [Parameter(Mandatory, Position = 2)]
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [string]$VstoreId
    )

    process {
        $target = if ($PSCmdlet.ParameterSetName -eq 'ById') { $Id } else { $Name }
        if ($PSCmdlet.ShouldProcess($target, "Rename protection group to '$NewName'")) {
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                return Set-DMProtectionGroup -WebSession $WebSession -Id $Id -NewName $NewName -VstoreId $VstoreId -Confirm:$false
            }
            return Set-DMProtectionGroup -WebSession $WebSession -Name $Name -NewName $NewName -VstoreId $VstoreId -Confirm:$false
        }
    }
}