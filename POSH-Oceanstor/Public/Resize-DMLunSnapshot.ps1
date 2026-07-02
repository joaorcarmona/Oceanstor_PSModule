<#
.SYNOPSIS
    Expands an OceanStor LUN snapshot.

.DESCRIPTION
    Resolves a snapshot name to its ID and sets its user capacity through the OceanStor snapshot REST resource.
    UserCapacity must be greater than the current snapshot capacity. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SnapShotName
    Name of the snapshot to expand. Valid values are checked against Get-DMLunSnapshot and support tab completion.

.PARAMETER UserCapacity
    New snapshot user capacity in sectors, as required by the REST API.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Resize-DMLunSnapshot -SnapShotName 'snap_lun01_before_patch' -UserCapacity 2147483648 -WhatIf

    Shows what would happen if the LUN snapshot capacity were expanded.

.NOTES
    Filename: Resize-DMLunSnapshot.ps1
#>
function Resize-DMLunSnapshot {
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
        [string]$SnapShotName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateRange(1, [uint64]::MaxValue)]
        [uint64]$UserCapacity
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $snapshot = @(Get-DMLunSnapshot -WebSession $session | Where-Object Name -EQ $SnapShotName)[0]
    if ($null -eq $snapshot) { throw "Could not resolve 'snapshot' — the object may have been removed since parameter validation." }

    if ($null -ne $snapshot.'User Capacity' -and $UserCapacity -le [uint64]$snapshot.'User Capacity') {
        throw "UserCapacity must be greater than the current snapshot capacity of $($snapshot.'User Capacity') sectors."
    }

    if ($PSCmdlet.ShouldProcess($SnapShotName, 'Expand LUN snapshot')) {
        $body = @{
            ID           = $snapshot.Id
            USERCAPACITY = $UserCapacity
        }
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snapshot/expand' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
