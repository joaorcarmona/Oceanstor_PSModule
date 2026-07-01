<#
.SYNOPSIS
    Rolls back an OceanStor file system snapshot.

.DESCRIPTION
    Rolls back a file system to an existing snapshot by resolving the source file system and snapshot names before calling the OceanStor API.
    This operation overwrites newer file-system data and may delete newer read-only snapshots, as described by the OceanStor REST interface.
    Use -WhatIf first when testing automation.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER FileSystemName
    Name of the source file system that will be rolled back.

.PARAMETER SnapshotName
    Name of the file-system snapshot to roll back from. Valid values are resolved from the selected file system.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Restore-DMFileSystemSnapshot -FileSystemName 'fs01' -SnapshotName 'snap_fs01_before_patch' -WhatIf

    Shows what would happen if fs01 were rolled back to the selected snapshot.

.NOTES
    Filename: Restore-DMFileSystemSnapshot.ps1
#>
function Restore-DMFileSystemSnapshot {
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
                    $deviceManager
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
                    $deviceManager
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
                    $deviceManager
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
                    $deviceManager
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
        $deviceManager
    }
    $snapshot = @(Get-DMFileSystemSnapshot -WebSession $session -FileSystemName $FileSystemName -SnapshotName $SnapshotName)[0]
    if ($null -eq $snapshot) { throw "Could not resolve 'snapshot' — the object may have been removed since parameter validation." }

    if ($PSCmdlet.ShouldProcess("$FileSystemName/$SnapshotName", 'Roll back file system snapshot')) {
        $body = @{ ID = $snapshot.Id }
        if ($snapshot.'vStore ID') {
            $body.vstoreId = $snapshot.'vStore ID'
        }
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'fssnapshot/rollback_fssnapshot' -BodyData $body
        return $response.error
    }
}
