function Get-DMFileSystemSnapshots {
    <#
    .SYNOPSIS
        Retrieves snapshots of a Huawei OceanStor file system.
    #>
    [CmdletBinding()]
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

        [Parameter(Position = 2)]
        [string]$SnapshotName
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $fileSystem = @(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    $resource = "fssnapshot?PARENTID=$($fileSystem.Id)"
    $response = invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource |
        Select-Object -ExpandProperty data
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
