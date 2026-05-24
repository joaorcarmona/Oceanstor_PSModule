function New-DMFileSystemSnapshot {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor file-system snapshot.

    .PARAMETER FileSystemName
        Name of the source file system. Valid values support tab completion
        and are resolved to the PARENTID sent to the REST interface.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 1)]
        [ValidatePattern('^[A-Za-z0-9_-]{1,255}$')]
        [string]$SnapshotName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $fileSystems = @(get-DMFileSystem -WebSession $session)
            $matchingItems = @($fileSystems | Where-Object Name -EQ $_)
            if ($matchingItems.Count -eq 1) { return $true }
            if ($matchingItems.Count -gt 1) { throw "FileSystemName is ambiguous because more than one file system is named '$_'." }
            throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$FileSystemName,

        [Parameter(Position = 3)]
        [ValidateLength(0, 1023)]
        [string]$Description,

        [Parameter(Position = 4)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$')]
        [string]$SnapTag
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $fileSystem = @(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    $body = @{
        NAME       = if ($SnapshotName) { $SnapshotName } else { "snap_$FileSystemName-$(Get-Date -Format 'yyyyMMddHHmmss')" }
        PARENTTYPE = 40
        PARENTID   = $fileSystem.Id
        snapType   = 1
    }
    if ($Description) { $body.description = $Description }
    if ($SnapTag) { $body.snapTag = $SnapTag }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'fssnapshot' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorFileSystemSnapshot]::new($response.data, $session)
    }

    return $response.error
}
