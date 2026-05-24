function Restore-DMFileSystemSnapshot {
    <#
    .SYNOPSIS
        Rolls back a file system to a Huawei OceanStor file-system snapshot.

    .DESCRIPTION
        This operation overwrites newer file-system data and may delete newer
        read-only snapshots, as described by the OceanStor REST interface.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $fileSystems = @(get-DMFileSystem -WebSession $session)
            $matches = @($fileSystems | Where-Object Name -EQ $_)
            if ($matches.Count -eq 1) { return $true }
            if ($matches.Count -gt 1) { throw "FileSystemName is ambiguous because more than one file system is named '$_'." }
            throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$FileSystemName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $snapshots = @(Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $FileSystemName)
            $matches = @($snapshots | Where-Object Name -EQ $_)
            if ($matches.Count -eq 1) { return $true }
            if ($matches.Count -gt 1) { throw "SnapshotName is ambiguous because more than one snapshot is named '$_'." }
            throw "Invalid SnapshotName. Valid values are: $($snapshots.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            if (-not $fakeBoundParameters.ContainsKey('FileSystemName')) { return }
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $fakeBoundParameters.FileSystemName).Name |
                Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$SnapshotName
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $snapshot = @(Get-DMFileSystemSnapshots -WebSession $session -FileSystemName $FileSystemName | Where-Object Name -EQ $SnapshotName)[0]

    if ($PSCmdlet.ShouldProcess("$FileSystemName/$SnapshotName", 'Roll back file system snapshot')) {
        $body = @{ ID = $snapshot.Id }
        if ($snapshot.'vStore ID') { $body.vstoreId = $snapshot.'vStore ID' }
        $response = invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'fssnapshot/rollback_fssnapshot' -BodyData $body
        return $response.error
    }
}
