function New-DMSnapshotConsistencyGroup {
    <#
    .SYNOPSIS
        Creates a snapshot consistency group from a protection group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidatePattern('^[A-Za-z0-9_.-]{1,255}$')]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMProtectionGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "ProtectionGroupName is ambiguous because more than one protection group is named '$_'."
                }
                throw "Invalid ProtectionGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$ProtectionGroupName,

        [Parameter(Position = 3)]
        [ValidateLength(1, 255)]
        [string]$Description
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $protectionGroup = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $ProtectionGroupName)[0]
    $body = @{ NAME = $Name; PARENTID = $protectionGroup.Id }
    if ($Description) {
        $body.DESCRIPTION = $Description
    }
    if ($protectionGroup.'vStore ID') {
        $body.vstoreId = $protectionGroup.'vStore ID'
    }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'SNAPSHOT_CONSISTENCY_GROUP' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorSnapshotConsistencyGroup]::new($response.data, $session)
    }

    return $response.error
}
