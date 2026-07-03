<#
.SYNOPSIS
    Removes a direct OceanStor LUN-to-host mapping.

.DESCRIPTION
    Deletes a direct host-to-LUN mapping via the OceanStor mapping interface, resolving both
    objects by name. Unlike Remove-DMHostGroupFromMappingView/Remove-DMLunGroupFromMappingView/
    Remove-DMPortGroupFromMappingView, this does not target an existing named mapping view -- the
    OceanStor REST API's legacy mappingview/REMOVE_ASSOCIATE endpoint only accepts host group, LUN
    group, or port group associations, not individual hosts or LUNs. The recommended mapping
    interface used here deletes the underlying mapping from the host/LUN pair alone, so there is
    no -MappingViewName parameter.
    The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple LUNs from the pipeline by property name. Each is resolved and unmapped from
    the same host independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is
    reported as a non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER LunName
    Name of the LUN to unmap from the host.

.PARAMETER HostName
    Name of the host to unmap the LUN from.

.PARAMETER VstoreId
    Optional vStore ID used to scope the mapping operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMLunFromMappingView -LunName 'data-lun' -HostName 'esx01' -WhatIf

    Shows what would happen if data-lun were unmapped from esx01.

.NOTES
    Filename: Remove-DMLunFromMappingView.ps1
#>
function Remove-DMLunFromMappingView {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [Parameter(Mandatory = $true, Position = 2)]
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

            $matchingLuns = @(Get-DMlunByName -WebSession $session -Name $LunName)
            if ($matchingLuns.Count -eq 0) {
                $luns = @(Get-DMlun -WebSession $session)
                throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
            }
            if ($matchingLuns.Count -gt 1) {
                throw "LunName is ambiguous because more than one LUN is named '$LunName'."
            }
            $lun = $matchingLuns[0]

            $matchingHosts = @(Get-DMhostbyName -WebSession $session -Name $HostName)
            if ($matchingHosts.Count -eq 0) {
                $hosts = @(Get-DMhost -WebSession $session)
                throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
            }
            if ($matchingHosts.Count -gt 1) {
                throw "HostName is ambiguous because more than one host is named '$HostName'."
            }
            $hostObject = $matchingHosts[0]

            $body = @{ hostId = $hostObject.Id; lunId = $lun.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$LunName <- $HostName", 'Remove LUN-host mapping')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'mapping' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
