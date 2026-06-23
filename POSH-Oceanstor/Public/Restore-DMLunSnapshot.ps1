<#
.SYNOPSIS
    Rolls back data using an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a snapshot name to its ID and starts a rollback operation through the OceanStor snapshot REST resource.
    This operation overwrites newer LUN data. Use -WhatIf first when testing automation.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER SnapShotName
    Name of the snapshot to roll back. Valid values are checked against Get-DMLunSnapshot and support tab completion.

.PARAMETER RollbackSpeed
    Rate for the rollback operation. Valid values are Low, Medium, High, and Highest. The default is Medium.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Restore-DMLunSnapshot -SnapShotName 'snap_lun01_before_patch' -RollbackSpeed High -WhatIf

    Shows what would happen if the LUN were rolled back from the selected snapshot at high speed.

.NOTES
    Filename: Restore-DMLunSnapshot.ps1
#>
function Restore-DMLunSnapshot {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

                $snapshots = @(Get-DMLunSnapshot -WebSession $session)
                $matchingSnapshots = @($snapshots | Where-Object Name -EQ $_)

                if ($matchingSnapshots.Count -eq 1) {
                    $true
                }
                elseif ($matchingSnapshots.Count -gt 1) {
                    throw "SnapShotName is ambiguous because more than one snapshot is named '$_'."
                }
                else {
                    throw "Invalid SnapShotName. Valid values are: $($snapshots.Name -join ', ')"
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

                (Get-DMLunSnapshot -WebSession $session).Name |
                    Sort-Object -Unique |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SnapShotName,

        [Parameter(Position = 2)]
        [ValidateSet('Low', 'Medium', 'High', 'Highest')]
        [string]$RollbackSpeed = 'Medium'
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $snapshot = @(Get-DMLunSnapshot -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]
    $speedValue = @{
        Low     = 1
        Medium  = 2
        High    = 3
        Highest = 4
    }[$RollbackSpeed]

    if ($PSCmdlet.ShouldProcess($SnapShotName, 'Roll back LUN snapshot')) {
        $body = @{
            ID            = $snapshot.Id
            ROLLBACKSPEED = $speedValue
        }
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snapshot/rollback' -BodyData $body
        return $response.error
    }
}
