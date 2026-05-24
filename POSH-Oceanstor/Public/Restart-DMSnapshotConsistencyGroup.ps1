function Restart-DMSnapshotConsistencyGroup {
    <#
    .SYNOPSIS
        Reactivates a Huawei OceanStor snapshot consistency group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $groups = @(Get-DMSnapshotConsistencyGroup -WebSession $session)
            $matchingItems = @($groups | Where-Object Name -EQ $_)
            if ($matchingItems.Count -eq 1) { return $true }
            if ($matchingItems.Count -gt 1) { throw "Name is ambiguous because more than one snapshot consistency group is named '$_'." }
            throw "Invalid snapshot consistency group Name. Valid values are: $($groups.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (Get-DMSnapshotConsistencyGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$Name
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $group = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
    $body = @{ ID = $group.Id }
    if ($group.'vStore ID') { $body.vstoreId = $group.'vStore ID' }

    if ($PSCmdlet.ShouldProcess($Name, 'Reactivate snapshot consistency group')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot_consistency_group/restore' -BodyData $body
        return $response.error
    }
}
