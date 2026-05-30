function New-DMLunSnapshotCopy {
    <#
    .SYNOPSIS
        Creates a copy of a Huawei OceanStor LUN snapshot.

    .DESCRIPTION
        Resolves a source snapshot name to its ID and creates a snapshot copy
        through the OceanStor snapshot REST resource.

    .PARAMETER WebSession
        Optional session for the REST call. If omitted, the deviceManager
        global variable is used.

    .PARAMETER SourceSnapShotName
        Name of the source snapshot. Valid values are checked against
        Get-DMLunSnapshots and support tab completion.

    .PARAMETER SnapshotCopyName
        Optional name of the copy. If omitted, copy_<source snapshot name> is
        used.

    .PARAMETER Description
        Optional description for the snapshot copy.

    .OUTPUTS
        OceanstorLunSnapshot when creation succeeds, otherwise the REST error.

    .EXAMPLE
        PS C:\> New-DMLunSnapshotCopy -SourceSnapShotName 'db-before-patch'

    .EXAMPLE
        PS C:\> New-DMLunSnapshotCopy -SourceSnapShotName 'db-before-patch' -SnapshotCopyName 'db-before-patch-copy'
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $deviceManager
                }

                $snapshots = @(Get-DMLunSnapshots -WebSession $session)
                $matchingSnapshots = @($snapshots | Where-Object Name -EQ $_)

                if ($matchingSnapshots.Count -eq 1) {
                    $true
                }
                elseif ($matchingSnapshots.Count -gt 1) {
                    throw "SourceSnapShotName is ambiguous because more than one snapshot is named '$_'."
                }
                else {
                    throw "Invalid SourceSnapShotName. Valid values are: $($snapshots.Name -join ', ')"
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $session = $fakeBoundParameters.WebSession
                }
                else {
                    $session = $deviceManager
                }

                (Get-DMLunSnapshots -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SourceSnapShotName,

        [Parameter(Position = 2)]
        [Alias('CopyName')]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$SnapshotCopyName,

        [Parameter(Position = 3)]
        [ValidateLength(0, 255)]
        [string]$Description
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $sourceSnapshot = @(Get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $SourceSnapShotName)[0]

    $resolvedCopyName = $SnapshotCopyName
    if (-not $resolvedCopyName) {
        $resolvedCopyName = "copy_$SourceSnapShotName"
        if ($resolvedCopyName.Length -gt 255) {
            throw 'The generated SnapshotCopyName exceeds the 255 character API limit. Specify SnapshotCopyName explicitly.'
        }
    }

    $body = @{
        ID   = $sourceSnapshot.Id
        NAME = $resolvedCopyName
    }

    if ($Description) {
        $body.Add('DESCRIPTION', $Description)
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot/createcopy' -BodyData $body

    if ($response.error.Code -eq 0) {
        return [OceanstorLunSnapshot]::new($response.data, $session)
    }

    return $response.error
}
