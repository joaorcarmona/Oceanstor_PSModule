<#
.SYNOPSIS
    Creates an OceanStor snapshot consistency group.

.DESCRIPTION
    Creates a snapshot consistency group from an existing protection group.
    The protection group is resolved by name and its vStore ID is passed through when available.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Name of the snapshot consistency group to create. The value may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER ProtectionGroupName
    Name of the protection group that will be used as the snapshot consistency group parent.

.PARAMETER Description
    Optional description for the snapshot consistency group. The value must be 1 to 255 characters when supplied.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorSnapshotConsistencyGroup
    Returns the created snapshot consistency group object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMSnapshotConsistencyGroup -Name 'scg-production' -ProtectionGroupName 'pg-production'

    Creates a snapshot consistency group from the pg-production protection group.

.EXAMPLE
    PS> New-DMSnapshotConsistencyGroup -Name 'scg-production' -ProtectionGroupName 'pg-production' -Description 'Pre-maintenance consistency point'

    Creates a snapshot consistency group with a description.

.NOTES
    Filename: New-DMSnapshotConsistencyGroup.ps1
#>
function New-DMSnapshotConsistencyGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9_.-]{1,255}$')]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
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
                    $script:CurrentOceanstorSession
                }
                (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$ProtectionGroupName,

        [Parameter(Position = 2)]
        [ValidateLength(1, 255)]
        [string]$Description
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $protectionGroup = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $ProtectionGroupName)[0]
    if ($null -eq $protectionGroup) { throw "Could not resolve 'protectionGroup' — the object may have been removed since parameter validation." }
    $body = @{ NAME = $Name; PARENTID = $protectionGroup.Id }
    if ($Description) {
        $body.DESCRIPTION = $Description
    }
    if ($protectionGroup.'vStore ID') {
        $body.vstoreId = $protectionGroup.'vStore ID'
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create snapshot consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'SNAPSHOT_CONSISTENCY_GROUP' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorSnapshotConsistencyGroup]::new($response.data, $session)
        }

        return $response.error
    }
}
