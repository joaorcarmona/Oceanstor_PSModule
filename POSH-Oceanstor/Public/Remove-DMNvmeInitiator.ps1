<#
.SYNOPSIS
    Removes a free NVMe over RoCE initiator from the OceanStor system.

.DESCRIPTION
    Deletes an existing free NVMe over RoCE initiator by NQN, optionally scoped to a vStore.
    Associated initiators must be removed from their host before deletion. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

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
function Remove-DMNvmeInitiator {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $initiators = @(Get-DMNvmeInitiator -WebSession $session -FreeInitiators)
                if ($initiators.Id -contains $candidate) {
                    return $true
                }
                throw "Invalid free NVMe over RoCE initiator NQN. Valid values are: $($initiators.Id -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMNvmeInitiator -WebSession $session -FreeInitiators).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Nqn,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $body = @{ ID = $Nqn }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }
    if ($PSCmdlet.ShouldProcess($Nqn, 'Remove free NVMe over RoCE initiator')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'NVMe_over_RoCE_initiator' -BodyData $body).error
    }
}
