<#
.SYNOPSIS
    Creates an OceanStor protection group.

.DESCRIPTION
    Creates a protection group through the API v2 protection group interface.
    LunGroupName and optional Vstore names are resolved to the IDs sent to the storage system.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER Name
    Name of the protection group to create. The value must be 1 to 255 characters.

.PARAMETER LunGroupName
    Name of the LUN group that backs the protection group. The name is validated against existing OceanStor LUN groups.

.PARAMETER Vstore
    Optional vStore name used to scope the protection group. The name is validated against existing OceanStor vStores.

.PARAMETER Description
    Optional description for the protection group. The value must be 1 to 255 characters when supplied.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorProtectionGroup
    Returns the created protection group object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMProtectionGroup -Name 'pg-production' -LunGroupName 'production-luns' -Description 'Production workload protection'

    Creates a protection group for the production-luns LUN group.

.EXAMPLE
    PS> New-DMProtectionGroup -Name 'pg-vstore-a' -LunGroupName 'tenant-a-luns' -Vstore 'vstore-a'

    Creates a protection group scoped to vstore-a.

.NOTES
    Filename: New-DMProtectionGroup.ps1
#>
function New-DMProtectionGroup {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $lunGroups = @(Get-DMlunGroup -WebSession $session)
                $matchingItems = @($lunGroups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$_'."
                }
                throw "Invalid LunGroupName. Valid values are: $($lunGroups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMlunGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [Parameter(Position = 3)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $vstores = @(Get-DMvStore -WebSession $session)
                $matchingItems = @($vstores | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "Vstore is ambiguous because more than one vStore is named '$_'."
                }
                throw "Invalid Vstore. Valid values are: $($vstores.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMvStore -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Vstore,

        [Parameter(Position = 4)]
        [ValidateLength(1, 255)]
        [string]$Description
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $lunGroup = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    $body = @{
        protectGroupName = $Name
        lunGroupId       = $lunGroup.Id
    }

    if ($Vstore) {
        $vstoreObject = @(Get-DMvStore -WebSession $session | Where-Object Name -EQ $Vstore)[0]
        $body.vstoreId = $vstoreObject.Id
    }
    if ($Description) {
        $body.description = $Description
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'protectgroup' -BodyData $body -ApiV2
    if ($response.error.Code -eq 0) {
        return [OceanstorProtectionGroup]::new($response.data, $session)
    }

    return $response.error
}
