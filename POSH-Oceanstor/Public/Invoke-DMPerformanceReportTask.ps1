function Invoke-DMPerformanceReportTask {
    <#
    .SYNOPSIS
        Runs a Huawei Oceanstor performance report task and waits for the export to be ready.

    .DESCRIPTION
        Triggers report generation via pms/report_task/export (GET, v2 API), then polls
        pms/report_task/task_log (GET, v2 API) until a new log entry for the task appears.

        task_log entries carry no status field on this array's firmware (Dorado V600R005C27,
        confirmed live 2026-07-06, see PerformanceGAP.md). This cmdlet snapshots the existing
        log IDs for the task before triggering the export, then treats the first newly-appeared
        log entry as ready -- confirmed correct against a live array, not a defensive guess.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Name of the report task to run. Mutually exclusive with Id (enforced by parameter set).

    .PARAMETER Id
        ID of the report task to run. Mutually exclusive with Name (enforced by parameter set).

    .PARAMETER PollIntervalSec
        Seconds to wait between task_log polls. Defaults to 3.

    .PARAMETER TimeoutSec
        Maximum seconds to wait for a new log entry before throwing. Defaults to 120.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        pscustomobject (PSTypeName 'OceanStor.PerformanceReportLog')

    .EXAMPLE
        PS> Invoke-DMPerformanceReportTask -Name 'lun-history'

    .EXAMPLE
        PS> Invoke-DMPerformanceReportTask -Id '1' -TimeoutSec 300

    .NOTES
        Filename: Invoke-DMPerformanceReportTask.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', DefaultParameterSetName = 'ByName')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [ValidateRange(1, 3600)]
        [int]$PollIntervalSec = 3,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSec = 120
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $task = @(Get-DMPerformanceReportTask -WebSession $session -Id $Id)[0]
            }
            else {
                $task = @(Get-DMPerformanceReportTask -WebSession $session | Where-Object Name -EQ $Name)[0]
            }
            if ($null -eq $task) { throw "Invoke-DMPerformanceReportTask: could not resolve the report task." }

            if (-not $PSCmdlet.ShouldProcess($task.Name, 'Run performance report task')) {
                return
            }

            $existingLogIds = @(
                Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "pms/report_task/task_log?task_id=$($task.Id)" -ApiV2 |
                    Select-DMResponseData |
                    ForEach-Object { if ($_.log_id) { $_.log_id } else { $_.id } }
            )

            $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "pms/report_task/export?task_id=$($task.Id)" -ApiV2
            $response | Assert-DMApiSuccess | Out-Null

            $deadline = (Get-Date).AddSeconds($TimeoutSec)
            do {
                $currentLogs = @(Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "pms/report_task/task_log?task_id=$($task.Id)" -ApiV2 | Select-DMResponseData)
                $newLog = $currentLogs | Where-Object { $(if ($_.log_id) { $_.log_id } else { $_.id }) -notin $existingLogIds } | Select-Object -First 1

                if ($newLog) {
                    return New-DMPerformanceReportLog -Raw $newLog -Session $session
                }

                if ((Get-Date) -ge $deadline) {
                    throw "Invoke-DMPerformanceReportTask: timed out after $TimeoutSec second(s) waiting for report task '$($task.Name)' to generate a new export log."
                }

                Start-Sleep -Seconds $PollIntervalSec
            } while ($true)
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
