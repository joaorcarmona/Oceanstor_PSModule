<#
.SYNOPSIS
    Removes an OceanStor host.

.DESCRIPTION
    Deletes an existing host by name, optionally scoped to a vStore.
    The host name is validated against existing OceanStor hosts before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple hosts from the pipeline by property name. Each host is resolved and removed
    independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a
    non-terminating error and does not stop the remaining hosts from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER HostName
    Name of the host to remove. The name is validated against existing OceanStor hosts.

.PARAMETER VstoreId
    Optional vStore ID used to scope the host removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMHost -HostName 'host01' -WhatIf

    Shows what would happen if host01 were removed.

.NOTES
    Filename: Remove-DMHost.ps1
#>
function Remove-DMHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
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

            $matchingItems = @(Get-DMhost -WebSession $session -Name $HostName)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid HostName '$HostName'. No host with that name exists."
            }
            if ($matchingItems.Count -gt 1) {
                throw "HostName is ambiguous because more than one host is named '$HostName'."
            }
            $hostObject = $matchingItems[0]

            $resource = "host/$($hostObject.Id)"
            if ($VstoreId) {
                $resource += "?vstoreId=$VstoreId"
            }

            if ($PSCmdlet.ShouldProcess($HostName, 'Remove host')) {
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
