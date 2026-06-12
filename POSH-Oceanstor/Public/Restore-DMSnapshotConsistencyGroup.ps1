<#
.SYNOPSIS
    Rolls back an OceanStor snapshot consistency group.

.DESCRIPTION
    Rolls back the LUNs in a snapshot consistency group by resolving the group name to the group ID before calling the OceanStor API.
    This operation overwrites newer data for the protected LUNs. Use -WhatIf first when testing automation.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER Name
    Name of the snapshot consistency group to roll back.

.PARAMETER RestoreSpeed
    Rate for the rollback operation. Valid values are Low, Medium, High, and Highest. The default is Medium.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Restore-DMSnapshotConsistencyGroup -Name 'scg-production' -RestoreSpeed High -WhatIf

    Shows what would happen if scg-production were rolled back at high speed.

.NOTES
    Filename: Restore-DMSnapshotConsistencyGroup.ps1
#>
function Restore-DMSnapshotConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMSnapshotConsistencyGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "Name is ambiguous because more than one snapshot consistency group is named '$_'."
                }
                throw "Invalid snapshot consistency group Name. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMSnapshotConsistencyGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Position = 2)]
        [ValidateSet('Low', 'Medium', 'High', 'Highest')]
        [string]$RestoreSpeed = 'Medium'
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $group = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
    $speedValue = @{ Low = 1; Medium = 2; High = 3; Highest = 4 }[$RestoreSpeed]
    $body = @{ ID = $group.Id; RESTORESPEED = $speedValue }
    if ($group.'vStore ID') {
        $body.vstoreId = $group.'vStore ID'
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Roll back snapshot consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'SNAPSHOT_CONSISTENCY_GROUP/rollback' -BodyData $body
        return $response.error
    }
}
