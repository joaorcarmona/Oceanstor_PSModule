<#
.SYNOPSIS
    Creates an OceanStor LUN snapshot.

.DESCRIPTION
    Creates a LUN snapshot through the OceanStor snapshot REST resource.
    When SnapshotName is omitted or empty, the cmdlet generates a name from the source LUN name and a compact UTC tick serial.
    The source LUN can be identified by Name, Id, or a piped LUN object. SourceLunName and SourceLunId
    are mutually exclusive. SourceLunName is validated at parameter-binding time with tab completion;
    SourceLunId is validated too, but has no tab completion.

    Accepts multiple source LUNs from the pipeline.
    Each is snapshotted independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is
    reported as a non-terminating error and does not stop the remaining LUNs from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SnapshotName
    Optional name of the snapshot to create.

.PARAMETER SourceLunName
    Name of the source LUN. Valid values are checked against Get-DMlun and support tab completion. Mutually exclusive with SourceLunId.

.PARAMETER SourceLunId
    Id of the source LUN. Valid values are checked against Get-DMlun, no tab completion. Mutually exclusive with SourceLunName.

.PARAMETER Description
    Optional description of the snapshot.

.PARAMETER ReadOnly
    Optional switch to request a read-only snapshot.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorLunSnapshot
    Returns the created LUN snapshot object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMLunSnapshot -SnapshotName 'db-before-patch' -SourceLunName 'production-db'

    Creates a named snapshot of the production-db LUN.

.EXAMPLE
    PS> New-DMLunSnapshot -WebSession $session -SnapshotName 'db-readonly' -SourceLunName 'production-db' -ReadOnly

    Creates a read-only snapshot using the supplied session.

.EXAMPLE
    PS> Get-DMLun 'production-db' | New-DMLunSnapshot

    Creates a snapshot of production-db via the pipeline.

.NOTES
    Filename: New-DMLunSnapshot.ps1
#>
function New-DMLunSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [AllowEmptyString()]
        [string]$SnapshotName,

        [Parameter(ValueFromPipeline = $true)]
        [psobject]$InputObject,

        [Parameter(Position = 0)]
        [Alias('Name')]
        [ValidateScript({
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $script:CurrentOceanstorSession
                }

                $luns = Get-DMlun -WebSession $session
                $matchingLuns = @($luns | Where-Object Name -EQ $_)

                if ($matchingLuns.Count -eq 1) {
                    $true
                }
                elseif ($matchingLuns.Count -gt 1) {
                    throw "SourceLunName is ambiguous because more than one LUN is named '$_'."
                }
                else {
                    throw 'Invalid SourceLunName.'
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

                (Get-DMlun -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SourceLunName,

        [Parameter()]
        [Alias('Id')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMlun -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                throw 'Invalid SourceLunId.'
            })]
        [string]$SourceLunId,

        [Parameter(Position = 1)]
        [string]$Description,

        [Parameter(Position = 2)]
        [switch]$ReadOnly
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            if ($InputObject -and ($PSBoundParameters.ContainsKey('SourceLunName') -or $PSBoundParameters.ContainsKey('SourceLunId'))) {
                throw 'Use either pipeline input or SourceLunName/SourceLunId, not both.'
            }
            if ($PSBoundParameters.ContainsKey('SourceLunName') -and $PSBoundParameters.ContainsKey('SourceLunId')) {
                throw 'SourceLunName and SourceLunId cannot be used together.'
            }

            if ($InputObject) {
                if ($InputObject.Id) {
                    $sourceLun = @(Get-DMlun -WebSession $session -Id $InputObject.Id)[0]
                    if ($null -eq $sourceLun) { throw "Could not resolve piped LUN Id '$($InputObject.Id)' - the object may have been removed." }
                }
                elseif ($InputObject.Name) {
                    $matchingLuns = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $InputObject.Name)
                    if ($matchingLuns.Count -eq 1) {
                        $sourceLun = $matchingLuns[0]
                    }
                    elseif ($matchingLuns.Count -gt 1) {
                        throw "Piped LUN name is ambiguous because more than one LUN is named '$($InputObject.Name)'."
                    }
                    else {
                        throw "Could not resolve piped LUN Name '$($InputObject.Name)' - the object may have been removed."
                    }
                }
                else {
                    throw 'Piped input must include an Id or Name property.'
                }
            }
            elseif ($PSBoundParameters.ContainsKey('SourceLunId')) {
                $sourceLun = @(Get-DMlun -WebSession $session -Id $SourceLunId)[0]
                if ($null -eq $sourceLun) { throw "Could not resolve 'SourceLunId' - the object may have been removed since parameter validation." }
            }
            elseif ($PSBoundParameters.ContainsKey('SourceLunName')) {
                $sourceLun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $SourceLunName)[0]
                if ($null -eq $sourceLun) { throw "Could not resolve 'SourceLunName' - the object may have been removed since parameter validation." }
            }
            else {
                throw 'SourceLunName, SourceLunId, or a piped LUN object is required.'
            }

            $body = @{
                TYPE       = 27
                PARENTTYPE = 11
                PARENTID   = $sourceLun.Id
            }

            if (-not [string]::IsNullOrWhiteSpace($SnapshotName)) {
                $body.Add('NAME', $SnapshotName)
            }
            else {
                $ticks = [DateTime]::UtcNow.Ticks
                $characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                $serial = ''
                do {
                    $remainder = [long]0
                    $ticks = [math]::DivRem($ticks, 36, [ref]$remainder)
                    $serial = $characters[[int]$remainder] + $serial
                } while ($ticks -gt 0)
                $body.Add('NAME', "$($sourceLun.Name)_SNAP_$serial")
            }

            if ($Description) {
                $body.Add('DESCRIPTION', $Description)
            }

            if ($ReadOnly) {
                $body.Add('isReadOnly', $true)
            }

            if ($PSCmdlet.ShouldProcess($sourceLun.Name, 'Create LUN snapshot')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot' -BodyData $body
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
