<#
.SYNOPSIS
    Creates an OceanStor LUN snapshot.

.DESCRIPTION
    Creates a LUN snapshot through the OceanStor snapshot REST resource.
    When SnapshotName is omitted, the cmdlet generates a name from the source LUN name and current timestamp.
    The source LUN can be identified by Name or by Id; Name and Id are mutually exclusive, enforced by
    PowerShell parameter sets. SourceLunName is validated at parameter-binding time with tab completion;
    SourceLunId is validated too, but has no tab completion.

    Accepts multiple source LUNs from the pipeline by property name (Name only; Id is not pipeline-bound).
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

    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false, Position = 0)]
        [string]$SnapshotName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 1)]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
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

        [Parameter(Position = 2)]
        [string]$Description,

        [Parameter(Position = 3)]
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

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $sourceLun = @(Get-DMlun -WebSession $session -Id $SourceLunId)[0]
                if ($null -eq $sourceLun) { throw "Could not resolve 'SourceLunId' - the object may have been removed since parameter validation." }
            }
            else {
                $sourceLun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $SourceLunName)[0]
                if ($null -eq $sourceLun) { throw "Could not resolve 'SourceLunName' - the object may have been removed since parameter validation." }
            }

            $body = @{
                TYPE       = 27
                PARENTTYPE = 11
                PARENTID   = $sourceLun.Id
            }

            if ($SnapshotName) {
                $body.Add('NAME', $SnapshotName)
            }
            else {
                $body.Add('NAME', "snap_$($sourceLun.Name)-$(Get-Date -Format 'yyyyMMddHHmmss')")
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
