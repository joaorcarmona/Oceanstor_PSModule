<#
.SYNOPSIS
    Associates an OceanStor host group with a mapping view.

.DESCRIPTION
    Adds an existing host group to an existing mapping view by resolving both objects by name.
    The cmdlet validates the mapping view and host group before calling the OceanStor API and supports -WhatIf and -Confirm.

    Accepts multiple host groups from the pipeline by property name. Each is resolved and associated
    independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a
    non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

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
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhostGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
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

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $groups = @(Get-DMhostGroup -WebSession $session)
            $matchingGroups = @($groups | Where-Object Name -EQ $HostGroupName)
            if ($matchingGroups.Count -eq 0) {
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            }
            if ($matchingGroups.Count -gt 1) {
                throw "HostGroupName is ambiguous because more than one host group is named '$HostGroupName'."
            }
            $group = $matchingGroups[0]

            $views = @(Get-DMMappingView -WebSession $session)
            $matchingViews = @($views | Where-Object Name -EQ $MappingViewName)
            if ($matchingViews.Count -eq 0) {
                throw "Invalid MappingViewName. Valid values are: $($views.Name -join ', ')"
            }
            if ($matchingViews.Count -gt 1) {
                throw "MappingViewName is ambiguous because more than one mapping view is named '$MappingViewName'."
            }
            $view = $matchingViews[0]

            $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 14; ASSOCIATEOBJID = $group.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$HostGroupName -> $MappingViewName", 'Associate host group with mapping view')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/CREATE_ASSOCIATE' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
