function New-DMSnapshotConsistencyGroupCopy {
    <#
    .SYNOPSIS
        Creates a copy of a snapshot consistency group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $groups = @(Get-DMSnapshotConsistencyGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "SourceName is ambiguous because more than one snapshot consistency group is named '$_'." }
                throw "Invalid SourceName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                (Get-DMSnapshotConsistencyGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$SourceName,

        [Parameter(Position = 2)]
        [ValidatePattern('^[A-Za-z0-9_.-]{1,255}$')]
        [string]$Name,

        [Parameter(Position = 3)]
        [ValidateLength(1, 255)]
        [string]$Description
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $source = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $SourceName)[0]
    $body = @{
        COPYSOURCEID = $source.Id
        NAME         = if ($Name) { $Name } else { "copy_$SourceName" }
    }
    if ($Description) { $body.DESCRIPTION = $Description }
    if ($source.'vStore ID') { $body.vstoreId = $source.'vStore ID' }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'CONSISTENCY_GROUP/createcopy' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorSnapshotConsistencyGroup]::new($response.data, $session)
    }

    return $response.error
}
