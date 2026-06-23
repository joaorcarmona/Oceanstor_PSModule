<#
.SYNOPSIS
    Removes an OceanStor host group from a mapping view.

.DESCRIPTION
    Removes an existing host group association from an existing mapping view by resolving both objects by name.
    The cmdlet validates the mapping view, host group, and current association before calling the OceanStor API. It supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER MappingViewName
    Name of the mapping view from which the host group will be removed.

.PARAMETER HostGroupName
    Name of the host group to remove from the mapping view.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMHostGroupFromMappingView -MappingViewName 'mv-prod' -HostGroupName 'production-hosts' -WhatIf

    Shows what would happen if the production-hosts host group were removed from mv-prod.

.NOTES
    Filename: Remove-DMHostGroupFromMappingView.ps1
#>
function Remove-DMHostGroupFromMappingView {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
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
                    $deviceManager
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
                    $deviceManager
                }
                $groups = @(Get-DMhostGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostGroupName is ambiguous because more than one host group is named '$_'."
                }
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMhostGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    if (-not $view) {
        throw "Mapping view '$MappingViewName' was not found."
    }
    $group = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    if (-not $group) {
        throw "Host group '$HostGroupName' was not found."
    }
    $associations = @(Get-DMMappingView -WebSession $session -HostGroupName $HostGroupName -VstoreId $VstoreId)
    if ($associations.Id -notcontains $view.Id) {
        throw "Host group '$HostGroupName' is not associated with mapping view '$MappingViewName'."
    }

    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 14; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$HostGroupName <- $MappingViewName", 'Remove host group from mapping view')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/REMOVE_ASSOCIATE' -BodyData $body).error
    }
}
