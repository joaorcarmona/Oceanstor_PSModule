<#
.SYNOPSIS
    Removes an OceanStor file-system snapshot.

.DESCRIPTION
    Deletes an existing file-system snapshot by resolving the source file system and snapshot names before calling the OceanStor API.
    The cmdlet validates both names and supports -WhatIf and -Confirm.

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

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $snapshots = @(Get-DMFileSystemSnapshot -WebSession $session -FileSystemName $FileSystemName -SnapshotName $_)
                $matchingItems = @($snapshots | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "SnapshotName is ambiguous because more than one snapshot is named '$_'."
                }
                throw "Invalid SnapshotName. Valid values are: $($snapshots.Name -join ', ')"
            })]
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

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $snapshot = @(Get-DMFileSystemSnapshot -WebSession $session -FileSystemName $FileSystemName -SnapshotName $SnapshotName)[0]
    if ($null -eq $snapshot) { throw "Could not resolve 'snapshot' — the object may have been removed since parameter validation." }

    if ($PSCmdlet.ShouldProcess("$FileSystemName/$SnapshotName", 'Remove file-system snapshot')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "fssnapshot/$($snapshot.Id)"
        return $response.error
    }
}
