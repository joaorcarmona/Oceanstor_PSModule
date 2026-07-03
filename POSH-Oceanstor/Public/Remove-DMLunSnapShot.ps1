<#
.SYNOPSIS
    Removes an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a LUN snapshot name to its snapshot ID and removes the snapshot through the OceanStor snapshot REST resource.
    The cmdlet validates the snapshot name and supports -WhatIf and -Confirm.

    Accepts multiple snapshots from the pipeline by property name. Each snapshot is resolved and
    removed independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is reported as
    a non-terminating error and does not stop the remaining snapshots from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SnapShotName
    Name of the LUN snapshot to remove. Valid values are checked against Get-DMLunSnapshot and support tab completion.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMLunSnapShot -SnapShotName 'db-before-patch' -WhatIf

    Shows what would happen if the LUN snapshot were removed.

.EXAMPLE
    PS> Remove-DMLunSnapShot -WebSession $session -SnapShotName 'db-before-patch' -Confirm:$false

    Removes the LUN snapshot using the supplied session without prompting for confirmation.

.NOTES
    Filename: Remove-DMLunSnapShot.ps1
#>
function Remove-DMLunSnapShot {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
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

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $snapshots = @(Get-DMLunSnapshot -WebSession $session)
            $matchingSnapshots = @($snapshots | Where-Object Name -EQ $SnapShotName)
            if ($matchingSnapshots.Count -eq 0) {
                throw "Invalid SnapShotName. Valid values are: $($snapshots.Name -join ', ')"
            }
            if ($matchingSnapshots.Count -gt 1) {
                throw "SnapShotName is ambiguous because more than one snapshot is named '$SnapShotName'."
            }
            $snapshot = $matchingSnapshots[0]

            if ($PSCmdlet.ShouldProcess($SnapShotName, 'Remove LUN snapshot')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "snapshot/$($snapshot.Id)"
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
