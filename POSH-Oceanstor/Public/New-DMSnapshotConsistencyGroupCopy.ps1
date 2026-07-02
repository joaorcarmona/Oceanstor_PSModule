<#
.SYNOPSIS
    Creates a copy of an OceanStor snapshot consistency group.

.DESCRIPTION
    Creates a copy of an existing snapshot consistency group.
    The source group is resolved by name and its vStore ID is passed through when available. When Name is omitted, copy_<source name> is used.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER SourceName
    Name of the source snapshot consistency group to copy.

.PARAMETER Name
    Optional name for the copy. The value may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER Description
    Optional description for the snapshot consistency group copy. The value must be 1 to 255 characters when supplied.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorSnapshotConsistencyGroup
    Returns the created snapshot consistency group copy object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMSnapshotConsistencyGroupCopy -SourceName 'scg-production'

    Creates a copy named copy_scg-production.

.EXAMPLE
    PS> New-DMSnapshotConsistencyGroupCopy -SourceName 'scg-production' -Name 'scg-production-copy'

    Creates a snapshot consistency group copy with an explicit name.

.NOTES
    Filename: New-DMSnapshotConsistencyGroupCopy.ps1
#>
function New-DMSnapshotConsistencyGroupCopy {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
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
                    throw "SourceName is ambiguous because more than one snapshot consistency group is named '$_'."
                }
                throw "Invalid SourceName. Valid values are: $($groups.Name -join ', ')"
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
        [string]$SourceName,

        [Parameter(Position = 2)]
        [ValidatePattern('^[A-Za-z0-9_.-]{1,255}$')]
        [string]$Name,

        [Parameter(Position = 3)]
        [ValidateLength(1, 255)]
        [string]$Description
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $source = @(Get-DMSnapshotConsistencyGroup -WebSession $session | Where-Object Name -EQ $SourceName)[0]
    if ($null -eq $source) { throw "Could not resolve 'source' — the object may have been removed since parameter validation." }
    $body = @{
        COPYSOURCEID = $source.Id
        NAME         = if ($Name) {
            $Name
        }
        else {
            "copy_$SourceName"
        }
    }
    if ($Description) {
        $body.DESCRIPTION = $Description
    }
    if ($source.'vStore ID') {
        $body.vstoreId = $source.'vStore ID'
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create snapshot consistency group copy')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'CONSISTENCY_GROUP/createcopy' -BodyData $body
        if ($response.error.Code -eq 0) {
            return [OceanstorSnapshotConsistencyGroup]::new($response.data, $session)
        }

        return $response.error
    }
}
