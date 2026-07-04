<#
.SYNOPSIS
    Removes an OceanStor snapshot consistency group.

.DESCRIPTION
    Deletes an existing snapshot consistency group by resolving its name to the group ID before calling the OceanStor API.
    The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple snapshot consistency groups from the pipeline by property name. Each group is
    resolved and removed independently: a failure (e.g. an invalid/ambiguous name, or a REST error)
    is reported as a non-terminating error and does not stop the remaining groups from being
    processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

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
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMSnapshotConsistencyGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Position = 1)]
        [switch]$DeleteDestinationLuns
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $groups = @(Get-DMSnapshotConsistencyGroup -WebSession $session)
            $matchingItems = @($groups | Where-Object Name -EQ $Name)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid snapshot consistency group Name. Valid values are: $($groups.Name -join ', ')"
            }
            if ($matchingItems.Count -gt 1) {
                throw "Name is ambiguous because more than one snapshot consistency group is named '$Name'."
            }
            $group = $matchingItems[0]

            $resource = "SNAPSHOT_CONSISTENCY_GROUP/$($group.Id)"
            if ($DeleteDestinationLuns.IsPresent) {
                $resource = "$resource?isDeleteDstLun=1"
            }

            if ($PSCmdlet.ShouldProcess($Name, 'Remove snapshot consistency group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
