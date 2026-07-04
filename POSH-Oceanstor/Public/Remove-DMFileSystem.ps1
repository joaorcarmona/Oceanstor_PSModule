<#
.SYNOPSIS
    Removes an OceanStor file system.

.DESCRIPTION
    Deletes an existing file system by name, optionally scoped to a vStore.
    Force and WORM flags are passed through to the OceanStor API when specified. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple file systems from the pipeline by property name. Each file system is resolved
    and removed independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is
    reported as a non-terminating error and does not stop the remaining file systems from being
    processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER FileSystemName
    Name of the file system to remove. The name is validated against existing OceanStor file systems.

.PARAMETER Force
    Sends forceDeleteFs=true with the delete request.

.PARAMETER Worm
    Sends SUBTYPE=1 with the delete request for WORM file-system removal.

.PARAMETER VstoreId
    Optional vStore ID used to scope the file-system removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMFileSystem -FileSystemName 'fs01' -WhatIf

    Shows what would happen if fs01 were removed.

.EXAMPLE
    PS> Remove-DMFileSystem -FileSystemName 'fs01' -Force -Confirm

    Prompts for confirmation and sends the force delete flag for fs01.

.NOTES
    Filename: Remove-DMFileSystem.ps1
#>
function Remove-DMFileSystem {
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
                (Get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$FileSystemName,

        [switch]$Force,

        [switch]$Worm,

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

            $fileSystems = @(Get-DMFileSystem -WebSession $session)
            $matchingItems = @($fileSystems | Where-Object Name -EQ $FileSystemName)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            }
            if ($matchingItems.Count -gt 1) {
                throw "FileSystemName is ambiguous because more than one file system is named '$FileSystemName'."
            }
            $fileSystem = $matchingItems[0]

            $parameters = @()
            if ($Force) {
                $parameters += 'forceDeleteFs=true'
            }
            if ($Worm) {
                $parameters += 'SUBTYPE=1'
            }
            if ($VstoreId) {
                $parameters += "vstoreId=$VstoreId"
            }
            $resource = "filesystem/$($fileSystem.Id)"
            if ($parameters.Count -gt 0) {
                $resource += "?$($parameters -join '&')"
            }

            if ($PSCmdlet.ShouldProcess($FileSystemName, 'Remove file system and its data')) {
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
