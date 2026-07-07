function Remove-DMPerformanceReportTask {
    <#
    .SYNOPSIS
        Removes a Huawei Oceanstor performance report task.

    .DESCRIPTION
        Removes a performance report task via the pms/report_task resource (v2 API).

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Name of the report task to remove. Mutually exclusive with Id (enforced by parameter set).

    .PARAMETER Id
        ID of the report task to remove. Mutually exclusive with Name (enforced by parameter set).

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Remove-DMPerformanceReportTask -Name 'lun-history'

    .EXAMPLE
        PS> Remove-DMPerformanceReportTask -Id '1'

    .NOTES
        Filename: Remove-DMPerformanceReportTask.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMPerformanceReportTask -WebSession $session | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "Name is ambiguous because more than one report task is named '$_'." }
                throw 'Invalid Name.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMPerformanceReportTask -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMPerformanceReportTask -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid Id.'
            })]
        [string]$Id
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $task = @(Get-DMPerformanceReportTask -WebSession $session -Id $Id)[0]
                if ($null -eq $task) { throw "Could not resolve 'Id' - the object may have been removed since parameter validation." }
            }
            else {
                $task = @(Get-DMPerformanceReportTask -WebSession $session | Where-Object Name -EQ $Name)[0]
                if ($null -eq $task) { throw "Could not resolve 'Name' - the object may have been removed since parameter validation." }
            }

            if ($PSCmdlet.ShouldProcess($task.Name, 'Remove performance report task')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "pms/report_task/$($task.Id)" -ApiV2
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
