<#
.SYNOPSIS
    Activates an OceanStor snapshot consistency group.

.DESCRIPTION
    Activates an existing snapshot consistency group by resolving its name to the group ID before calling the OceanStor API.
    The group vStore ID is passed through when available. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Name of the snapshot consistency group to activate.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Enable-DMSnapshotConsistencyGroup -Name 'scg-production' -WhatIf

    Shows what would happen if scg-production were activated.

.NOTES
    Filename: Enable-DMSnapshotConsistencyGroup.ps1
#>
function Enable-DMSnapshotConsistencyGroup {
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
                    $script:CurrentOceanstorSession
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
                    $script:CurrentOceanstorSession
                }
                (Get-DMSnapshotConsistencyGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $group = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    $body = @{ ID = $group.Id }
    if ($group.'vStore ID') {
        $body.vstoreId = $group.'vStore ID'
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Activate snapshot consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot_consistency_group/activate' -BodyData $body
        return $response.error
    }
}
