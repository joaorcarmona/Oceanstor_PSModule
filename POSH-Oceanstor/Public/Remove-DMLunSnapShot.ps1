function Remove-DMLunSnapShot {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor LUN snapshot.

    .DESCRIPTION
        Resolves a LUN snapshot name to its snapshot ID and removes the
        snapshot through the OceanStor snapshot REST resource.

    .PARAMETER WebSession
        Optional session for the REST call. If omitted, the deviceManager
        global variable is used.

    .PARAMETER SnapShotName
        Name of the LUN snapshot to remove. Valid values are checked against
        Get-DMLunSnapshots and support tab completion.

    .OUTPUTS
        REST error status returned by the storage system.

    .EXAMPLE
        PS C:\> Remove-DMLunSnapShot -SnapShotName 'db-before-patch'

    .EXAMPLE
        PS C:\> Remove-DMLunSnapShot -WebSession $session -SnapShotName 'db-before-patch' -Confirm:$false
    #>
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

                $snapshots = @(Get-DMLunSnapshots -WebSession $session)
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

                (Get-DMLunSnapshots -WebSession $session).Name |
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

    $snapshot = @(Get-DMLunSnapshots -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]

    if ($PSCmdlet.ShouldProcess($SnapShotName, 'Remove LUN snapshot')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "snapshot/$($snapshot.Id)"
        return $response.error
    }
}
