function Remove-DMNvmeInitiator {
    <#
    .SYNOPSIS
        Removes a free NVMe over RoCE initiator from the OceanStor system.

    .DESCRIPTION
        Deletes an existing free NVMe over RoCE initiator by NQN, optionally scoped to a vStore.
        Associated initiators must be removed from their host before deletion. The cmdlet supports -WhatIf and -Confirm.

        Accepts multiple initiators from the pipeline by property name. Each is resolved and removed
        independently: a failure (e.g. an invalid NQN, or a REST error) is reported as a
        non-terminating error and does not stop the remaining initiators from being processed.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Nqn
        NQN of the free NVMe over RoCE initiator to remove.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the initiator operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns the OceanStor API error object.

    .EXAMPLE
        PS> Remove-DMNvmeInitiator -Nqn 'nqn.2026-06.test:host01' -WhatIf

        Shows what would happen if the free NVMe over RoCE initiator were removed.

    .NOTES
        Filename: Remove-DMNvmeInitiator.ps1
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
                (Get-DMNvmeInitiator -WebSession $session -FreeInitiators).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Nqn,

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

            $initiators = @(Get-DMNvmeInitiator -WebSession $session -FreeInitiators)
            if ($initiators.Id -notcontains $Nqn) {
                throw "Invalid free NVMe over RoCE initiator NQN. Valid values are: $($initiators.Id -join ', ')"
            }

            $body = @{ ID = $Nqn }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }
            if ($PSCmdlet.ShouldProcess($Nqn, 'Remove free NVMe over RoCE initiator')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'NVMe_over_RoCE_initiator' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
