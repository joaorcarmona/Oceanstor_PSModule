<#
.SYNOPSIS
    Removes an OceanStor snapshot consistency group.

.DESCRIPTION
    Deletes an existing snapshot consistency group by resolving its name to the group ID before calling the OceanStor API.
    The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER Name
    Name of the snapshot consistency group to remove.

.PARAMETER DeleteDestinationLuns
    Sends isDeleteDstLun=1 with the delete request to request deletion of destination LUNs associated with the consistency group.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMSnapshotConsistencyGroup -Name 'scg-production' -WhatIf

    Shows what would happen if scg-production were removed.

.EXAMPLE
    PS> Remove-DMSnapshotConsistencyGroup -Name 'scg-production' -DeleteDestinationLuns -Confirm

    Prompts for confirmation and requests deletion of associated destination LUNs.

.NOTES
    Filename: Remove-DMSnapshotConsistencyGroup.ps1
#>
function Remove-DMSnapshotConsistencyGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

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
        [switch]$DeleteDestinationLuns
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $group = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    $resource = "SNAPSHOT_CONSISTENCY_GROUP/$($group.Id)"
    if ($DeleteDestinationLuns.IsPresent) {
        $resource = "$resource?isDeleteDstLun=1"
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Remove snapshot consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
