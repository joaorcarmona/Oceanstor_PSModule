<#
.SYNOPSIS
    Removes an OceanStor file system.

.DESCRIPTION
    Deletes an existing file system by name, optionally scoped to a vStore.
    Force and WORM flags are passed through to the OceanStor API when specified. The cmdlet supports -WhatIf and -Confirm.

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
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $fileSystems = @(Get-DMFileSystem -WebSession $session)
                $matchingItems = @($fileSystems | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "FileSystemName is ambiguous because more than one file system is named '$_'."
                }
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            })]
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

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    if ($null -eq $fileSystem) { throw "Could not resolve 'fileSystem' — the object may have been removed since parameter validation." }
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
        return $response.error
    }
}
