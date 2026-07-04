<#
.SYNOPSIS
    Removes an OceanStor port group from a mapping view.

.DESCRIPTION
    Removes an existing port group association from an existing mapping view by resolving both objects by name.
    The cmdlet validates the mapping view, port group, and current association before calling the OceanStor API. It supports -WhatIf and -Confirm.

    Accepts multiple port groups from the pipeline by property name. Each is resolved and processed
    independently: a failure (e.g. an invalid/ambiguous name, or the group not being associated) is
    reported as a non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER MappingViewName
    Name of the mapping view from which the port group will be removed.

.PARAMETER PortGroupName
    Name of the port group to remove from the mapping view.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMPortGroupFromMappingView -MappingViewName 'mv-prod' -PortGroupName 'fc-front-end' -WhatIf

    Shows what would happen if the fc-front-end port group were removed from mv-prod.

.NOTES
    Filename: Remove-DMPortGroupFromMappingView.ps1
#>
function Remove-DMPortGroupFromMappingView {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

            $associations = @(Get-DMMappingView -WebSession $session -PortGroupName $PortGroupName -VstoreId $VstoreId)
            if ($associations.Id -notcontains $view.Id) {
                throw "Port group '$PortGroupName' is not associated with mapping view '$MappingViewName'."
            }

            $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 257; ASSOCIATEOBJID = $group.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$PortGroupName <- $MappingViewName", 'Remove port group from mapping view')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/REMOVE_ASSOCIATE' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
