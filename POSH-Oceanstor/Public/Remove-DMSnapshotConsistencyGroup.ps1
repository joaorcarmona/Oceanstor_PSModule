function Remove-DMSnapshotConsistencyGroup {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor snapshot consistency group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $groups = @(Get-DMSnapshotConsistencyGroup -WebSession $session)
            $matches = @($groups | Where-Object Name -EQ $_)
            if ($matches.Count -eq 1) { return $true }
            if ($matches.Count -gt 1) { throw "Name is ambiguous because more than one snapshot consistency group is named '$_'." }
            throw "Invalid snapshot consistency group Name. Valid values are: $($groups.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (Get-DMSnapshotConsistencyGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$Name,

        [Parameter(Position = 2)]
        [switch]$DeleteDestinationLuns
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $group = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
    $resource = "SNAPSHOT_CONSISTENCY_GROUP/$($group.Id)"
    if ($DeleteDestinationLuns.IsPresent) { $resource = "$resource?isDeleteDstLun=1" }

    if ($PSCmdlet.ShouldProcess($Name, 'Remove snapshot consistency group')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
