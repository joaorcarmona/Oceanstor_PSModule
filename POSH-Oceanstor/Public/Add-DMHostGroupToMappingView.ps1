<#
.SYNOPSIS
    Associates an OceanStor host group with a mapping view.

.DESCRIPTION
    Adds an existing host group to an existing mapping view by resolving both objects by name.
    The cmdlet validates the mapping view and host group before calling the OceanStor API and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER MappingViewName
    Name of the mapping view that will receive the host group.

.PARAMETER HostGroupName
    Name of the host group to associate with the mapping view.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Add-DMHostGroupToMappingView -MappingViewName 'mv-prod' -HostGroupName 'production-hosts' -WhatIf

    Shows what would happen if the production-hosts host group were associated with mv-prod.

.NOTES
    Filename: Add-DMHostGroupToMappingView.ps1
#>
function Add-DMHostGroupToMappingView {
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
                    $deviceManager
                }
                if (@(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $_).Count -eq 1) {
                    return $true
                }
                throw "Invalid MappingViewName. Valid values are: $((Get-DMMappingView -WebSession $session).Name -join ', ')"
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
                if (@(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $_).Count -eq 1) {
                    return $true
                }
                throw "Invalid HostGroupName. Valid values are: $((Get-DMhostGroup -WebSession $session).Name -join ', ')"
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
    $group = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 14; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$HostGroupName -> $MappingViewName", 'Associate host group with mapping view')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/CREATE_ASSOCIATE' -BodyData $body).error
    }
}
