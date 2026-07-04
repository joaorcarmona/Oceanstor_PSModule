<#
.SYNOPSIS
    Associates an OceanStor port group with a mapping view.

.DESCRIPTION
    Adds an existing port group to an existing mapping view by resolving both objects by name.
    The cmdlet validates the mapping view and port group before calling the OceanStor API and supports -WhatIf and -Confirm.

    Accepts multiple port groups from the pipeline by property name. Each is resolved and associated
    independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a
    non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER MappingViewName
    Name of the mapping view that will receive the port group.

.PARAMETER PortGroupName
    Name of the port group to associate with the mapping view.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Add-DMPortGroupToMappingView -MappingViewName 'mv-prod' -PortGroupName 'fc-front-end' -WhatIf

    Shows what would happen if the fc-front-end port group were associated with mv-prod.

.NOTES
    Filename: Add-DMPortGroupToMappingView.ps1
#>
function Add-DMPortGroupToMappingView {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
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
                (Get-DMPortGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$PortGroupName,

        [Parameter(Mandatory = $true, Position = 1)]
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

            $groups = @(Get-DMPortGroup -WebSession $session)
            $matchingGroups = @($groups | Where-Object Name -EQ $PortGroupName)
            if ($matchingGroups.Count -eq 0) {
                throw "Invalid PortGroupName. Valid values are: $($groups.Name -join ', ')"
            }
            if ($matchingGroups.Count -gt 1) {
                throw "PortGroupName is ambiguous because more than one port group is named '$PortGroupName'."
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

            $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 257; ASSOCIATEOBJID = $group.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$PortGroupName -> $MappingViewName", 'Associate port group with mapping view')) {
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
