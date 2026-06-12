<#
.SYNOPSIS
    Removes an iSCSI initiator association from an OceanStor host.

.DESCRIPTION
    Detaches an iSCSI initiator identifier from the specified host without deleting the initiator from the storage system.
    The cmdlet validates the host name and initiator membership before calling the OceanStor API. It supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER HostName
    Name of the host from which the iSCSI initiator should be removed.

.PARAMETER Identifier
    iSCSI initiator identifier to remove from the host.

.PARAMETER VstoreId
    Optional vStore ID used to scope the initiator operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMIscsiInitiatorFromHost -HostName 'host01' -Identifier 'iqn.2026-06.test:host01' -WhatIf

    Shows what would happen if the iSCSI initiator were detached from host01.

.NOTES
    Filename: Remove-DMIscsiInitiatorFromHost.ps1
#>
function Remove-DMIscsiInitiatorFromHost {
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
                $hosts = @(Get-DMhosts -WebSession $session)
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
                (Get-DMhosts -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
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
                $hostObject = @(Get-DMhosts -WebSession $session | Where-Object Name -EQ $selectedHostName)[0]
                $initiators = @(Get-DMHostInitiators -WebSession $session -InitatorType ISCSI -HostId $hostObject.Id)
                if ($initiators.Id -contains $candidate) {
                    return $true
                }
                throw "Invalid iSCSI initiator for host '$selectedHostName'. Valid values are: $($initiators.Id -join ', ')"
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
                (Get-DMIscsiInitiator -WebSession $session -HostName $fakeBoundParameters.HostName).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Identifier,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $body = @{ ID = $Identifier }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }
    if ($PSCmdlet.ShouldProcess("$HostName/$Identifier", 'Remove iSCSI initiator from host')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'iscsi_initiator/remove_iscsi_from_host' -BodyData $body).error
    }
}
