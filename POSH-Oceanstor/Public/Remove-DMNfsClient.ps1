<#
.SYNOPSIS
    Removes an OceanStor NFS share client.

.DESCRIPTION
    Deletes an existing NFS share authorization client by name, optionally scoped to a vStore.
    The client name is validated against existing OceanStor NFS file clients before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple clients from the pipeline by property name. Each client is resolved and removed
    independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a
    non-terminating error and does not stop the remaining clients from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER ClientName
    Name of the NFS share client to remove. The name is validated against existing OceanStor NFS file clients.

.PARAMETER VstoreId
    Optional vStore ID used to scope the NFS client removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMNfsClient -ClientName 'client01' -WhatIf

    Shows what would happen if client01 were removed.

.NOTES
    Filename: Remove-DMNfsClient.ps1
#>
function Remove-DMNfsClient {
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
                (Get-DMnfsFileClient -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$ClientName,

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

            $clients = @(Get-DMnfsFileClient -WebSession $session)
            $matchingItems = @($clients | Where-Object Name -EQ $ClientName)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid ClientName. Valid values are: $($clients.Name -join ', ')"
            }
            if ($matchingItems.Count -gt 1) {
                throw "ClientName is ambiguous because more than one NFS client is named '$ClientName'."
            }
            $client = $matchingItems[0]

            $resource = "NFS_SHARE_AUTH_CLIENT/$($client.Id)"
            if ($VstoreId) {
                $resource += "?vstoreId=$VstoreId"
            }

            if ($PSCmdlet.ShouldProcess($ClientName, 'Remove NFS share client')) {
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
