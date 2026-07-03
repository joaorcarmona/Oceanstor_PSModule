function Remove-DMMappingView {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor mapping view.

    .DESCRIPTION
        Deletes an existing mapping view by name, optionally scoped to a vStore.

        Accepts multiple mapping views from the pipeline by property name. Each mapping view is
        resolved and removed independently: a failure (e.g. an invalid/ambiguous name, or a REST
        error) is reported as a non-terminating error and does not stop the remaining mapping views
        from being processed.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER MappingViewName
        Name of the mapping view to remove.

    .PARAMETER VstoreId
        Optional vStore identifier to scope the deletion request.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        Returns the API error object from the delete operation.

    .EXAMPLE
        PS> Remove-DMMappingView -MappingViewName 'mv-prod' -WhatIf

    .NOTES
        Filename: Remove-DMMappingView.ps1
    #>
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

            $views = @(Get-DMMappingView -WebSession $session)
            $matchingItems = @($views | Where-Object Name -EQ $MappingViewName)
            if ($matchingItems.Count -eq 0) {
                throw "Invalid MappingViewName. Valid values are: $($views.Name -join ', ')"
            }
            if ($matchingItems.Count -gt 1) {
                throw "MappingViewName is ambiguous because more than one mapping view is named '$MappingViewName'."
            }
            $view = $matchingItems[0]

            $resource = "mappingview/$($view.Id)"
            if ($VstoreId) {
                $resource += "?vstoreId=$VstoreId"
            }

            if ($PSCmdlet.ShouldProcess($MappingViewName, 'Remove mapping view')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
