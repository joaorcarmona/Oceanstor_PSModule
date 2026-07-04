<#
.SYNOPSIS
    Removes an OceanStor file-system snapshot.

.DESCRIPTION
    Deletes an existing file-system snapshot by resolving the source file system and snapshot names before calling the OceanStor API.
    The cmdlet validates both names and supports -WhatIf and -Confirm.

    Accepts multiple snapshots from the pipeline by property name (all piped snapshots must belong to
    the same FileSystemName). Each snapshot is resolved and removed independently: a failure (e.g. an
    invalid/ambiguous name, or a REST error) is reported as a non-terminating error and does not stop
    the remaining snapshots from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER FileSystemName
    Name of the source file system that contains the snapshot.

.PARAMETER SnapshotName
    Name of the file-system snapshot to remove. Valid values are resolved from the selected file system.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMFileSystemSnapshot -FileSystemName 'fs01' -SnapshotName 'snap_fs01_before_patch' -WhatIf

    Shows what would happen if the snapshot were removed from fs01.

.NOTES
    Filename: Remove-DMFileSystemSnapshot.ps1
#>
function Remove-DMFileSystemSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
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

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('FileSystemName')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMFileSystemSnapshot -WebSession $session -FileSystemName $fakeBoundParameters.FileSystemName).Name |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SnapshotName
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $snapshots = @(Get-DMFileSystemSnapshot -WebSession $session -FileSystemName $FileSystemName -SnapshotName $SnapshotName)
            $matchingItems = @($snapshots | Where-Object Name -EQ $SnapshotName)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid SnapshotName. Valid values are: $($snapshots.Name -join ', ')"
            }
            if ($matchingItems.Count -gt 1) {
                throw "SnapshotName is ambiguous because more than one snapshot is named '$SnapshotName'."
            }
            $snapshot = $matchingItems[0]

            if ($PSCmdlet.ShouldProcess("$FileSystemName/$SnapshotName", 'Remove file-system snapshot')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "fssnapshot/$($snapshot.Id)"
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
