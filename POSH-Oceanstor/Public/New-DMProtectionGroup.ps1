<#
.SYNOPSIS
    Creates an OceanStor protection group.

.DESCRIPTION
    Creates a protection group through the API v2 protection group interface.
    LunGroupName/LunGroupId and the optional Vstore name are resolved to the IDs sent to the
    storage system. The backing LUN group is optional; when neither LunGroupName nor LunGroupId is
    supplied, the protection group is created without one.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Name of the protection group to create. The value must be 1 to 255 characters.

.PARAMETER LunGroupName
    Optional name of the LUN group that backs the protection group. The name is validated against existing OceanStor LUN groups and supports tab completion. Mutually exclusive with LunGroupId. When neither is supplied, the protection group is created without a backing LUN group.

.PARAMETER LunGroupId
    Optional Id of the LUN group that backs the protection group. Validated against existing OceanStor LUN groups, no tab completion. Mutually exclusive with LunGroupName.

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

.EXAMPLE
    PS> New-DMProtectionGroup -Name 'pg-empty'

    Creates a protection group with no backing LUN group.

.EXAMPLE
    PS> New-DMProtectionGroup -Name 'pg-production' -LunGroupId 12

.NOTES
    Filename: New-DMProtectionGroup.ps1
#>
function New-DMProtectionGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByLunGroupName')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByLunGroupName', Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $lunGroups = @(Get-DMlunGroup -WebSession $session)
                $matchingItems = @($lunGroups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$_'."
                }
                throw 'Invalid LunGroupName.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlunGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [Parameter(ParameterSetName = 'ByLunGroupId')]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMlunGroup -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid LunGroupId.'
            })]
        [string]$LunGroupId,

        [Parameter(Position = 3)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
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
                    $script:CurrentOceanstorSession
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
        $script:CurrentOceanstorSession
    }
    $body = @{
        protectGroupName = $Name
    }

    if ($LunGroupName) {
        $lunGroup = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
        if ($null -eq $lunGroup) { throw "Could not resolve 'LunGroupName' - the object may have been removed since parameter validation." }
        $body.lunGroupId = $lunGroup.Id
    }
    elseif ($LunGroupId) {
        $body.lunGroupId = $LunGroupId
    }

    if ($Vstore) {
        $vstoreObject = @(Get-DMvStore -WebSession $session | Where-Object Name -EQ $Vstore)[0]
        if ($null -eq $vstoreObject) { throw "Could not resolve 'vstoreObject' — the object may have been removed since parameter validation." }
        $body.vstoreId = $vstoreObject.Id
    }
    if ($Description) {
        $body.description = $Description
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create protection group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'protectgroup' -BodyData $body -ApiV2
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorProtectionGroup]::new($response.data, $session)
        }

        return $response.error
    }
}
