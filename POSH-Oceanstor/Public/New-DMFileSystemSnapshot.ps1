<#
.SYNOPSIS
    Creates an OceanStor file-system snapshot.

.DESCRIPTION
    Creates a snapshot for an existing OceanStor file system.
    When SnapshotName is omitted, the cmdlet generates a name from the file-system name and current timestamp.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER SnapshotName
    Optional snapshot name. The value must be 1 to 255 characters and may contain letters, numbers, underscores, or hyphens.

.PARAMETER FileSystemName
    Name of the source file system. The name is validated against existing OceanStor file systems and resolved to the parent ID sent to the REST interface.

.PARAMETER Description
    Optional description for the snapshot. The value can be up to 1023 characters.

.PARAMETER SnapTag
    Optional snapshot tag. The value must start with a letter or number and may contain letters, numbers, underscores, periods, or hyphens.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorFileSystemSnapshot
    Returns the created file-system snapshot object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMFileSystemSnapshot -FileSystemName 'fs01' -SnapshotName 'snap_fs01_before_patch'

    Creates a named snapshot for fs01.

.EXAMPLE
    PS> New-DMFileSystemSnapshot -FileSystemName 'fs01' -Description 'Pre-maintenance snapshot' -SnapTag 'maintenance'

    Creates a timestamp-named snapshot for fs01 with a description and tag.

.NOTES
    Filename: New-DMFileSystemSnapshot.ps1
#>
function New-DMFileSystemSnapshot {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 1)]
        [ValidatePattern('^[A-Za-z0-9_-]{1,255}$')]
        [string]$SnapshotName,

        [Parameter(Mandatory = $true, Position = 2)]
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

        [Parameter(Position = 3)]
        [ValidateLength(0, 1023)]
        [string]$Description,

        [Parameter(Position = 4)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$')]
        [string]$SnapTag
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    $body = @{
        NAME       = if ($SnapshotName) {
            $SnapshotName
        }
        else {
            "snap_$FileSystemName-$(Get-Date -Format 'yyyyMMddHHmmss')"
        }
        PARENTTYPE = 40
        PARENTID   = $fileSystem.Id
        snapType   = 1
    }
    if ($Description) {
        $body.description = $Description
    }
    if ($SnapTag) {
        $body.snapTag = $SnapTag
    }

    if ($PSCmdlet.ShouldProcess($SnapshotName, 'Create file-system snapshot')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'fssnapshot' -BodyData $body
        if ($response.error.Code -eq 0) {
            return [OceanstorFileSystemSnapshot]::new($response.data, $session)
        }

        return $response.error
    }
}
