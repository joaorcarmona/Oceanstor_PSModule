<#
.SYNOPSIS
    Creates a copy of an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a source snapshot name or Id to its ID and creates a snapshot copy through the OceanStor snapshot REST resource.
    When SnapshotCopyName is omitted, copy_<source snapshot name> is used.
    The source snapshot can be identified by Name or by Id; Name and Id are mutually exclusive, enforced by
    PowerShell parameter sets. SourceSnapShotName is validated at parameter-binding time with tab completion;
    SourceSnapShotId is validated too, but has no tab completion.

    Accepts multiple source snapshots from the pipeline by property name. Each is copied independently: a
    failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a non-terminating error and
    does not stop the remaining snapshots from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SourceSnapShotName
    Name of the source snapshot. Valid values are checked against Get-DMLunSnapshot and support tab completion. Mutually exclusive with SourceSnapShotId.

.PARAMETER SourceSnapShotId
    Id of the source snapshot. Valid values are checked against Get-DMLunSnapshot, no tab completion. Mutually exclusive with SourceSnapShotName.

.PARAMETER SnapshotCopyName
    Optional name of the copy. The value must be 1 to 255 characters and may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER Description
    Optional description for the snapshot copy.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorLunSnapshot
    Returns the created snapshot copy object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMLunSnapshotCopy -SourceSnapShotName 'db-before-patch'

    Creates a copy named copy_db-before-patch.

.EXAMPLE
    PS> New-DMLunSnapshotCopy -SourceSnapShotName 'db-before-patch' -SnapshotCopyName 'db-before-patch-copy'

    Creates a snapshot copy with an explicit name.

.EXAMPLE
    PS> Get-DMLunSnapshot -Id 5 | New-DMLunSnapshotCopy

    Creates a copy of the piped snapshot.

.NOTES
    Filename: New-DMLunSnapshotCopy.ps1
#>
function New-DMLunSnapshotCopy {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $script:CurrentOceanstorSession
                }

                $snapshots = @(Get-DMLunSnapshot -WebSession $session)
                $matchingSnapshots = @($snapshots | Where-Object Name -EQ $_)

                if ($matchingSnapshots.Count -eq 1) {
                    $true
                }
                elseif ($matchingSnapshots.Count -gt 1) {
                    throw "SourceSnapShotName is ambiguous because more than one snapshot is named '$_'."
                }
                else {
                    throw 'Invalid SourceSnapShotName.'
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $session = $fakeBoundParameters.WebSession
                }
                else {
                    $session = $script:CurrentOceanstorSession
                }

                (Get-DMLunSnapshot -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SourceSnapShotName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMLunSnapshot -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                throw 'Invalid SourceSnapShotId.'
            })]
        [string]$SourceSnapShotId,

        [Parameter(Position = 2)]
        [Alias('CopyName')]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$SnapshotCopyName,

        [Parameter(Position = 3)]
        [ValidateLength(0, 255)]
        [string]$Description
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $sourceSnapshot = @(Get-DMLunSnapshot -WebSession $session -Id $SourceSnapShotId)[0]
                if ($null -eq $sourceSnapshot) { throw "Could not resolve 'SourceSnapShotId' - the object may have been removed since parameter validation." }
            }
            else {
                $sourceSnapshot = @(Get-DMLunSnapshot -WebSession $session | Where-Object Name -EQ $SourceSnapShotName)[0]
                if ($null -eq $sourceSnapshot) { throw "Could not resolve 'SourceSnapShotName' - the object may have been removed since parameter validation." }
            }

            $resolvedCopyName = $SnapshotCopyName
            if (-not $resolvedCopyName) {
                $resolvedCopyName = "copy_$($sourceSnapshot.Name)"
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

            if ($PSCmdlet.ShouldProcess($resolvedCopyName, 'Create LUN snapshot copy')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot/createcopy' -BodyData $body
                $response = $response | Assert-DMApiSuccess

                if ($response.error.Code -eq 0) {
                    return [OceanstorLunSnapshot]::new($response.data, $session)
                }

                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
