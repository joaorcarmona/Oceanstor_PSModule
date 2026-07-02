<#
.SYNOPSIS
    Activates an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a snapshot name to its ID and activates it through the OceanStor snapshot REST resource.
    The cmdlet validates the snapshot name and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SnapShotName
    Name of the snapshot to activate. Valid values are checked against Get-DMLunSnapshot and support tab completion.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Enable-DMLunSnapshot -SnapShotName 'snap_lun01_before_patch' -WhatIf

    Shows what would happen if the LUN snapshot were activated.

.NOTES
    Filename: Enable-DMLunSnapshot.ps1
#>
function Enable-DMLunSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

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
                    throw "Invalid SnapShotName. Valid values are: $($snapshots.Name -join ', ')"
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
        [string]$SnapShotName
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $snapshot = @(Get-DMLunSnapshot -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]
    if ($null -eq $snapshot) { throw "Could not resolve 'snapshot' — the object may have been removed since parameter validation." }

    if ($PSCmdlet.ShouldProcess($SnapShotName, 'Activate LUN snapshot')) {
        $body = @{ SNAPSHOTLIST = @($snapshot.Id) }
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot/activate' -BodyData $body
        return $response.error
    }
}
