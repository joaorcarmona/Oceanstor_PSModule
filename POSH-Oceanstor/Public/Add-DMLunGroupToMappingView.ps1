<#
.SYNOPSIS
    Associates an OceanStor LUN group with a mapping view.

.DESCRIPTION
    Adds an existing LUN group to an existing mapping view by resolving both objects by name.
    The cmdlet validates the mapping view and LUN group before calling the OceanStor API and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER MappingViewName
    Name of the mapping view that will receive the LUN group.

.PARAMETER LunGroupName
    Name of the LUN group to associate with the mapping view.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Add-DMLunGroupToMappingView -MappingViewName 'mv-prod' -LunGroupName 'production-luns' -WhatIf

    Shows what would happen if the production-luns LUN group were associated with mv-prod.

.NOTES
    Filename: Add-DMLunGroupToMappingView.ps1
#>
function Add-DMLunGroupToMappingView {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
                $views = @(Get-DMMappingView -WebSession $session)
                $matchingItems = @($views | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "MappingViewName is ambiguous because more than one mapping view is named '$_'."
                }
                throw "Invalid MappingViewName. Valid values are: $($views.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMMappingView -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$MappingViewName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $groups = @(Get-DMlunGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$_'."
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

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    if ($null -eq $view) { throw "Could not resolve 'view' — the object may have been removed since parameter validation." }
    if (-not $view) {
        throw "Mapping view '$MappingViewName' was not found."
    }
    $group = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    if (-not $group) {
        throw "LUN group '$LunGroupName' was not found."
    }
    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 256; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$LunGroupName -> $MappingViewName", 'Associate LUN group with mapping view')) {
        return ((Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/CREATE_ASSOCIATE' -BodyData $body) | Assert-DMApiSuccess).error
    }
}
