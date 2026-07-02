<#
.SYNOPSIS
    Creates an OceanStor LUN snapshot.

.DESCRIPTION
    Creates a LUN snapshot through the OceanStor snapshot REST resource.
    When SnapshotName is omitted, the cmdlet generates a name from the source LUN name and current timestamp.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SnapshotName
    Optional name of the snapshot to create.

.PARAMETER SourceLunName
    Name of the source LUN. Valid values are checked against Get-DMlun and support tab completion. The selected LUN ID is sent to the API.

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

.NOTES
    Filename: New-DMLunSnapshot.ps1
#>
function New-DMLunSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SnapshotName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 2)]
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
                    throw "Invalid SourceLunName. Valid values are: $($luns.Name -join ', ')"
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

        [Parameter(Position = 3)]
        [string]$Description,

        [Parameter(Position = 4)]
        [switch]$ReadOnly
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $sourceLun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $SourceLunName)[0]
    if ($null -eq $sourceLun) { throw "Could not resolve 'sourceLun' — the object may have been removed since parameter validation." }

    $body = @{
        TYPE       = 27
        PARENTTYPE = 11
        PARENTID   = $sourceLun.Id
    }

    if ($SnapshotName) {
        $body.Add('NAME', $SnapshotName)
    }
    else {
        $body.Add('NAME', "snap_$($SourceLunName)-$(Get-Date -Format 'yyyyMMddHHmmss')")
    }

    if ($Description) {
        $body.Add('DESCRIPTION', $Description)
    }

    if ($ReadOnly) {
        $body.Add('isReadOnly', $true)
    }

    if ($PSCmdlet.ShouldProcess($SnapshotName, 'Create LUN snapshot')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot' -BodyData $body
        $response = $response | Assert-DMApiSuccess

        if ($response.error.Code -eq 0) {
            return [OceanstorLunSnapshot]::new($response.data, $session)
        }

        return $response.error
    }
}
