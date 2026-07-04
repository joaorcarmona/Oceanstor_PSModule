<#
.SYNOPSIS
    Reactivates an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a snapshot name or Id to its ID and replaces its existing point-in-time data with current source LUN data.
    This changes the snapshot contents. The cmdlet supports -WhatIf and -Confirm.
    The snapshot can be identified by Name or by Id; Name and Id are mutually exclusive, enforced by PowerShell
    parameter sets. SnapShotName is validated at parameter-binding time with tab completion; SnapShotId is
    validated too, but has no tab completion.

    Accepts multiple snapshots from the pipeline by property name. Each is reactivated independently: a
    failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a non-terminating error and
    does not stop the remaining snapshots from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SnapShotName
    Name of the snapshot to reactivate. Valid values are checked against Get-DMLunSnapshot and support tab completion. Mutually exclusive with SnapShotId.

.PARAMETER SnapShotId
    Id of the snapshot to reactivate. Valid values are checked against Get-DMLunSnapshot, no tab completion. Mutually exclusive with SnapShotName.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Restart-DMLunSnapshot -SnapShotName 'snap_lun01_before_patch' -WhatIf

    Shows what would happen if the LUN snapshot were reactivated.

.EXAMPLE
    PS> Get-DMLunSnapshot -Id 5 | Restart-DMLunSnapshot

    Reactivates the piped snapshot.

.NOTES
    Filename: Restart-DMLunSnapshot.ps1
#>
function Restart-DMLunSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
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
                    throw "SnapShotName is ambiguous because more than one snapshot is named '$_'."
                }
                else {
                    throw 'Invalid SnapShotName.'
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
        [string]$SnapShotName,

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
                throw 'Invalid SnapShotId.'
            })]
        [string]$SnapShotId
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
                $snapshot = @(Get-DMLunSnapshot -WebSession $session -Id $SnapShotId)[0]
                if ($null -eq $snapshot) { throw "Could not resolve 'SnapShotId' - the object may have been removed since parameter validation." }
            }
            else {
                $snapshot = @(Get-DMLunSnapshot -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]
                if ($null -eq $snapshot) { throw "Could not resolve 'SnapShotName' - the object may have been removed since parameter validation." }
            }

            if ($PSCmdlet.ShouldProcess($snapshot.Name, 'Reactivate LUN snapshot')) {
                $body = @{ ID = $snapshot.Id }
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snapshot/reactive' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
