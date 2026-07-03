function Remove-DMIscsiInitiator {
    <#
    .SYNOPSIS
        Removes a free iSCSI initiator from the OceanStor system.

    .DESCRIPTION
        Deletes an existing free iSCSI initiator by identifier, optionally scoped to a vStore.
        Associated initiators must be removed from their host before deletion. The cmdlet supports -WhatIf and -Confirm.

        Accepts multiple initiators from the pipeline by property name. Each is resolved and removed
        independently: a failure (e.g. an invalid identifier, or a REST error) is reported as a
        non-terminating error and does not stop the remaining initiators from being processed.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Identifier
        Identifier of the free iSCSI initiator to remove.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the initiator operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns the OceanStor API error object.

    .EXAMPLE
        PS> Remove-DMIscsiInitiator -Identifier 'iqn.2026-06.test:host01' -WhatIf

        Shows what would happen if the free iSCSI initiator were removed.

    .NOTES
        Filename: Remove-DMIscsiInitiator.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMIscsiInitiator -WebSession $session -FreeInitiators).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Identifier,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $initiators = @(Get-DMIscsiInitiator -WebSession $session -FreeInitiators)
            if ($initiators.Id -notcontains $Identifier) {
                throw "Invalid free iSCSI initiator identifier. Valid values are: $($initiators.Id -join ', ')"
            }

            $resource = "iscsi_initiator/$Identifier"
            if ($VstoreId) {
                $resource += "?vstoreId=$VstoreId"
            }
            if ($PSCmdlet.ShouldProcess($Identifier, 'Remove free iSCSI initiator')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
