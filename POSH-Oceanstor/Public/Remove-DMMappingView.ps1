function Remove-DMMappingView {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor mapping view.

    .DESCRIPTION
        Deletes an existing mapping view by name, optionally scoped to a vStore.

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
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $views = @(Get-DMMappingView -WebSession $session)
                $matchingItems = @($views | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "MappingViewName is ambiguous because more than one mapping view is named '$candidate'."
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
    $resource = "mappingview/$($view.Id)"
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    if ($PSCmdlet.ShouldProcess($MappingViewName, 'Remove mapping view')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource).error
    }
}
