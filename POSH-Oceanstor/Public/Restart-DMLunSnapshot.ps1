<#
.SYNOPSIS
    Reactivates an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a snapshot name to its ID and replaces its existing point-in-time data with current source LUN data.
    This changes the snapshot contents. The cmdlet validates the snapshot name and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER SnapShotName
    Name of the snapshot to reactivate. Valid values are checked against Get-DMLunSnapshot and support tab completion.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Restart-DMLunSnapshot -SnapShotName 'snap_lun01_before_patch' -WhatIf

    Shows what would happen if the LUN snapshot were reactivated.

.NOTES
    Filename: Restart-DMLunSnapshot.ps1
#>
function Restart-DMLunSnapshot {
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
        [string]$SnapShotName
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $snapshot = @(Get-DMLunSnapshot -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]

    if ($PSCmdlet.ShouldProcess($SnapShotName, 'Reactivate LUN snapshot')) {
        $body = @{ ID = $snapshot.Id }
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snapshot/reactive' -BodyData $body
        return $response.error
    }
}
