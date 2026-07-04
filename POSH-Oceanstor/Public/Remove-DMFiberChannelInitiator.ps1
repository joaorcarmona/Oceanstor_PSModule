function Remove-DMFiberChannelInitiator {
    <#
    .SYNOPSIS
        Removes a free Fibre Channel initiator from the OceanStor system.

    .DESCRIPTION
        Deletes an existing free Fibre Channel initiator by WWN, optionally scoped to a vStore.
        Associated initiators must be removed from their host before deletion. The cmdlet supports -WhatIf and -Confirm.

        Accepts multiple initiators from the pipeline by property name. Each is resolved and removed
        independently: a failure (e.g. an invalid WWN, or a REST error) is reported as a
        non-terminating error and does not stop the remaining initiators from being processed.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER WWN
        WWN of the free Fibre Channel initiator to remove.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the initiator operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns the OceanStor API error object.

    .EXAMPLE
        PS> Remove-DMFiberChannelInitiator -WWN '5001438000000001' -WhatIf

        Shows what would happen if the free Fibre Channel initiator were removed.

    .NOTES
        Filename: Remove-DMFiberChannelInitiator.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
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
                (Get-DMFiberChannelInitiator -WebSession $session -FreeInitiators).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$WWN,

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

            $initiators = @(Get-DMFiberChannelInitiator -WebSession $session -FreeInitiators)
            if ($initiators.Id -notcontains $WWN) {
                throw "Invalid free Fibre Channel initiator WWN. Valid values are: $($initiators.Id -join ', ')"
            }

            $resource = "fc_initiator/$([uri]::EscapeDataString($WWN))"
            if ($VstoreId) {
                $resource += "?vstoreId=$([uri]::EscapeDataString($VstoreId))"
            }
            if ($PSCmdlet.ShouldProcess($WWN, 'Remove free Fibre Channel initiator')) {
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
