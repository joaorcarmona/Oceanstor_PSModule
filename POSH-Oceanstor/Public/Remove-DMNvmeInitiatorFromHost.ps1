<#
.SYNOPSIS
    Removes an NVMe over RoCE initiator association from an OceanStor host.

.DESCRIPTION
    Detaches an NVMe over RoCE initiator NQN from the specified host without deleting the initiator from the storage system.
    The cmdlet validates the host name and initiator membership before calling the OceanStor API. It supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER HostName
    Name of the host from which the NVMe over RoCE initiator should be removed.

.PARAMETER Nqn
    NVMe over RoCE initiator NQN to remove from the host.

.PARAMETER VstoreId
    Optional vStore ID used to scope the initiator operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMNvmeInitiatorFromHost -HostName 'host01' -Nqn 'nqn.2026-06.test:host01' -WhatIf

    Shows what would happen if the NVMe over RoCE initiator were detached from host01.

.NOTES
    Filename: Remove-DMNvmeInitiatorFromHost.ps1
#>
function Remove-DMNvmeInitiatorFromHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

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
                $hosts = @(Get-DMhost -WebSession $session)
                $matchingItems = @($hosts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $selectedHostName = [string]$HostName
                $hostObject = @(Get-DMhost -WebSession $session | Where-Object Name -EQ $selectedHostName)[0]
                $resource = "NVMe_over_RoCE_initiator/associate?ASSOCIATEOBJTYPE=21&ASSOCIATEOBJID=$($hostObject.Id)"
                $initiators = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource).data)
                if ($initiators.ID -contains $candidate) {
                    return $true
                }
                throw "Invalid NVMe over RoCE initiator NQN for host '$selectedHostName'. Valid values are: $($initiators.ID -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('HostName')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMNvmeInitiator -WebSession $session -HostName $fakeBoundParameters.HostName).Id | Where-Object { $_ -like "$wordToComplete*" }
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
    $hostObject = @(Get-DMhost -WebSession $session | Where-Object Name -EQ $HostName)[0]
    $body = @{
        ID               = $hostObject.Id
        ASSOCIATEOBJTYPE = 57870
        ASSOCIATEOBJID   = $Nqn
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }
    if ($PSCmdlet.ShouldProcess("$HostName/$Nqn", 'Remove NVMe over RoCE initiator from host')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'host/remove_associate' -BodyData $body).error
    }
}
