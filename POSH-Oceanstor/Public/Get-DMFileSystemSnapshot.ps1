<#
.SYNOPSIS
    Retrieves OceanStor file-system snapshots.

.DESCRIPTION
    Gets snapshots for a specific OceanStor file system and optionally filters the returned snapshots by name.
    Returned objects use the OceanstorFileSystemSnapshot class and include a default display set for common snapshot properties.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER FileSystemName
    Name of the source file system. The name is validated against existing OceanStor file systems.

.PARAMETER SnapshotName
    Optional snapshot name to return. When omitted, all snapshots for the selected file system are returned.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorFileSystemSnapshot

.EXAMPLE
    PS> Get-DMFileSystemSnapshot -FileSystemName 'fs01'

    Returns all snapshots for fs01.

.EXAMPLE
    PS> Get-DMFileSystemSnapshot -FileSystemName 'fs01' -SnapshotName 'snap_fs01'

    Returns the snap_fs01 snapshot from fs01.

.NOTES
    Filename: Get-DMFileSystemSnapshot.ps1
#>
function Get-DMFileSystemSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding()]
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

        [Parameter(Position = 2)]
        [string]$SnapshotName
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]

    if ($SnapshotName) {
        $snapshotId = "$($fileSystem.Id)@$SnapshotName"
        $directResponse = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "fssnapshot/$snapshotId"
        $directError = if ($null -ne $directResponse) { $directResponse.PSObject.Properties['error'] } else { $null }
        $directData  = if ($null -ne $directResponse) { $directResponse.PSObject.Properties['data']  } else { $null }
        $response = if (($null -eq $directError -or $directError.Value.Code -eq 0) -and $null -ne $directData) {
            @($directData.Value)
        }
        else {
            @()
        }
    }
    else {
        $response = @()
    }

    if (@($response).Count -eq 0) {
        $listResult = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "fssnapshot?filter=PARENTID:$($fileSystem.Id)"
        $response = if ($null -ne $listResult -and $null -ne $listResult.data) { @($listResult.data) } else { @() }
        if (@($response).Count -eq 0) {
            $listResult = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "fssnapshot?PARENTID=$($fileSystem.Id)"
            $response = if ($null -ne $listResult -and $null -ne $listResult.data) { @($listResult.data) } else { @() }
        }
    }
    $defaultDisplaySet = 'Id', 'Name', 'Source File System Name', 'Health Status', 'Snapshot Type', 'Timestamp'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $snapshots = [System.Collections.ArrayList]::new()

    foreach ($snapshotData in @($response)) {
        $snapshot = [OceanstorFileSystemSnapshot]::new($snapshotData, $session)
        if (-not $SnapshotName -or $snapshot.Name -eq $SnapshotName) {
            $snapshot | Add-Member MemberSet PSStandardMembers $standardMembers -Force
            [void]$snapshots.Add($snapshot)
        }
    }

    return $snapshots
}

Set-Alias -Name Get-DMFileSystemSnapshots -Value Get-DMFileSystemSnapshot
