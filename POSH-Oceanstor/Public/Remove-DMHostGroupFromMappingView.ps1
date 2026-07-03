<#
.SYNOPSIS
    Removes an OceanStor host group from a mapping view.

.DESCRIPTION
    Removes an existing host group association from an existing mapping view by resolving both objects by name.
    The cmdlet validates the mapping view, host group, and current association before calling the OceanStor API. It supports -WhatIf and -Confirm.

    Accepts multiple host groups from the pipeline by property name. Each is resolved and processed
    independently: a failure (e.g. an invalid/ambiguous name, or the group not being associated) is
    reported as a non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

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

            $associations = @(Get-DMMappingView -WebSession $session -HostGroupName $HostGroupName -VstoreId $VstoreId)
            if ($associations.Id -notcontains $view.Id) {
                throw "Host group '$HostGroupName' is not associated with mapping view '$MappingViewName'."
            }

            $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 14; ASSOCIATEOBJID = $group.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$HostGroupName <- $MappingViewName", 'Remove host group from mapping view')) {
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
