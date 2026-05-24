function Restore-DMLunSnapshot {
    <#
    .SYNOPSIS
        Rolls back data using a Huawei OceanStor LUN snapshot.

    .DESCRIPTION
        Resolves a snapshot name to its ID and starts a rollback operation
        through the OceanStor snapshot REST resource.

    .PARAMETER WebSession
        Optional session for the REST call. If omitted, the deviceManager
        global variable is used.

    .PARAMETER SnapShotName
        Name of the snapshot to roll back. Valid values are checked against
        get-DMLunSnapshots and support tab completion.

    .PARAMETER RollbackSpeed
        Rate for the rollback operation. The REST API default is Medium.

    .OUTPUTS
        REST error status returned by the storage system.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [ValidateScript({
            if ($WebSession) {
                $session = $WebSession
            } else {
                $session = $deviceManager
            }

            $snapshots = @(get-DMLunSnapshots -WebSession $session)
            $matchingSnapshots = @($snapshots | Where-Object Name -EQ $_)

            if ($matchingSnapshots.Count -eq 1) {
                $true
            } elseif ($matchingSnapshots.Count -gt 1) {
                throw "SnapShotName is ambiguous because more than one snapshot is named '$_'."
            } else {
                throw "Invalid SnapShotName. Valid values are: $($snapshots.Name -join ', ')"
            }
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            if ($fakeBoundParameters.ContainsKey('WebSession')) {
                $session = $fakeBoundParameters.WebSession
            } else {
                $session = $deviceManager
            }

            (get-DMLunSnapshots -WebSession $session).Name |
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
    } else {
        $session = $deviceManager
    }

    $snapshot = @(get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]
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
        $response = invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snapshot/rollback' -BodyData $body
        return $response.error
    }
}
