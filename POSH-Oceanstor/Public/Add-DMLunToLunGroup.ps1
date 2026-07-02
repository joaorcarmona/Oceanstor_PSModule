<#
.SYNOPSIS
    Associates an OceanStor LUN with a LUN group.

.DESCRIPTION
    Adds an existing LUN to an existing LUN group. The LUN can be supplied by name or by piping a LUN object with a Name property.
    Optional host LUN ID settings can be supplied for the association. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Lun
    LUN object to add to the LUN group. The object must expose a Name property and can be supplied from the pipeline.

.PARAMETER LunName
    Name of the LUN to add to the LUN group. This is required when a LUN object is not supplied through the pipeline.

.PARAMETER LunGroupName
    Name of the LUN group that will receive the LUN. The name is validated against existing OceanStor LUN groups.

.PARAMETER HostLunId
    Specific host LUN ID to assign to the LUN association. Cannot be used with StartHostLunId.

.PARAMETER StartHostLunId
    Starting host LUN ID to use when assigning host LUN IDs. Cannot be used with HostLunId.

.PARAMETER Force
    Adds the force flag to the OceanStor association request.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Add-DMLunToLunGroup -LunName 'lun01' -LunGroupName 'production-luns' -WhatIf

    Shows what would happen if lun01 were added to the production-luns LUN group.

.EXAMPLE
    PS> Get-DMlun | Where-Object Name -EQ 'lun02' | Add-DMLunToLunGroup -LunGroupName 'production-luns' -HostLunId 12

    Adds lun02 to the production-luns LUN group and requests host LUN ID 12.

.NOTES
    Filename: Add-DMLunToLunGroup.ps1
#>
function Add-DMLunToLunGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(ValueFromPipeline = $true, Position = 1)]
        [pscustomobject]$Lun,

        [Parameter(Position = 2)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $luns = @(Get-DMlun -WebSession $session)
                $matchingItems = @($luns | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunName is ambiguous because more than one LUN is named '$candidate'."
                }
                throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 3)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $groups = @(Get-DMlunGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$candidate'."
                }
                throw "Invalid LunGroupName. Valid values are: $($groups.Name -join ', ')"
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

        [ValidateRange(0, 4095)]
        [int]$HostLunId,

        [ValidateRange(0, 4095)]
        [int]$StartHostLunId,

        [switch]$Force,

        [string]$VstoreId
    )

    if ($PSBoundParameters.ContainsKey('HostLunId') -and $PSBoundParameters.ContainsKey('StartHostLunId')) {
        throw 'HostLunId and StartHostLunId cannot be specified together.'
    }

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }

    $resolvedLunName = if ($Lun -and $Lun.PSObject.Properties.Name -contains 'Name') {
        $Lun.Name
    }
    elseif ($LunName) {
        $LunName
    }
    else {
        throw 'LunName is required. Pass a LUN name or pipe a LUN object with a Name property.'
    }

    $lun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $resolvedLunName)[0]
    if ($null -eq $lun) { throw "Could not resolve 'lun' — the object may have been removed since parameter validation." }
    $group = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = 11
        ASSOCIATEOBJID   = $lun.Id
    }
    if ($PSBoundParameters.ContainsKey('HostLunId')) {
        $body.hostLunID = $HostLunId
    }
    if ($PSBoundParameters.ContainsKey('StartHostLunId')) {
        $body.startHostLunId = $StartHostLunId
    }
    if ($Force) {
        $body.force = $true
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$resolvedLunName -> $LunGroupName", 'Associate LUN with LUN group')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'lungroup/associate' -BodyData $body).error
    }
}
