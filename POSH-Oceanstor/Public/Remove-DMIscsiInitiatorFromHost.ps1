function Remove-DMIscsiInitiatorFromHost {
    <#
    .SYNOPSIS
        Removes an iSCSI initiator association from an OceanStor host.

    .DESCRIPTION
        Detaches an iSCSI initiator identifier from the specified host without deleting the initiator from the storage system.
        The cmdlet validates the host name and initiator membership before calling the OceanStor API. It supports -WhatIf and -Confirm.

        Accepts multiple initiators from the pipeline by property name (all piped initiators must
        belong to the same HostName). Each is resolved and processed independently: a failure (e.g. an
        invalid identifier, or an invalid host name) is reported as a non-terminating error and does
        not stop the remaining initiators from being processed.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('HostName')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMIscsiInitiator -WebSession $session -HostName $fakeBoundParameters.HostName).Id | Where-Object { $_ -like "$wordToComplete*" }
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

            $matchingHosts = @(Get-DMhost -WebSession $session -Name $HostName)
            if ($matchingHosts.Count -eq 0) {
                throw "Invalid HostName '$HostName'. No host with that name exists."
            }
            if ($matchingHosts.Count -gt 1) {
                throw "HostName is ambiguous because more than one host is named '$HostName'."
            }
            $hostObject = $matchingHosts[0]

            $initiators = @(Get-DMHostInitiator -WebSession $session -InitiatorType ISCSI -HostId $hostObject.Id)
            if ($initiators.Id -notcontains $Identifier) {
                throw "Invalid iSCSI initiator for host '$HostName'. Valid values are: $($initiators.Id -join ', ')"
            }

            $body = @{ ID = $Identifier }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }
            if ($PSCmdlet.ShouldProcess("$HostName/$Identifier", 'Remove iSCSI initiator from host')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'iscsi_initiator/remove_iscsi_from_host' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
