function Get-DMPerformanceHistory {
    <#
    .SYNOPSIS
        Retrieves historical/ranged performance samples for OceanStor objects.

    .DESCRIPTION
        The performance_data endpoint used by Get-DMPerformance only ever returns the current
        sample, so historical/ranged queries have to be driven through the separate
        pms/report_task workflow instead: create a Customer-time-segment report task, run it,
        wait for the export, download the zip, and parse the CSV inside.

        This cmdlet is a convenience wrapper around that pipeline (New-DMPerformanceReportTask,
        Invoke-DMPerformanceReportTask, Save-DMPerformanceReportFile, Import-DMPerformanceReportCsv)
        for callers who just want OceanStor.PerformanceSample objects for a time range, without
        managing the underlying report task lifecycle themselves. The report task and its export
        log are removed automatically afterwards unless -KeepReportTask is specified.

        The report zip's CSV column layout has not been confirmed against a live array. Rather
        than guess at header text, this cmdlet maps the last N columns of each row positionally
        against the -Metric list, in the exact order that was submitted to the report task at
        creation time (the module authored that order, so it is the one thing that is certain).
        Any leading columns are inspected by name for an object-ID- or time-like header; when none
        is found, ObjectId/Timestamp are left blank/MinValue on the resulting sample. See
        PerformanceGAP.md Phase 4 notes.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER ObjectType
        The type of object to retrieve performance history for.

    .PARAMETER ObjectId
        One or more object IDs to retrieve performance history for. Pipeline-able.

    .PARAMETER Metric
        One or more friendly metric names (see Get-DMPerformanceIndicatorMap). Defaults to
        Get-DMPerformance's own default set when omitted.

    .PARAMETER StartTime
        Window start.

    .PARAMETER EndTime
        Window end.

    .PARAMETER ComputeMode
        How samples are aggregated within the reporting window: Avg (default) or Max.

    .PARAMETER TimeoutSec
        Maximum seconds to wait for the report task's export to finish generating. Defaults to 120.

    .PARAMETER KeepReportTask
        Skip removing the underlying report task and export log afterwards. Useful for
        troubleshooting the raw report task/export/CSV directly.

    .INPUTS
        System.String

    .OUTPUTS
        System.Collections.ArrayList

    .EXAMPLE
        PS> Get-DMPerformanceHistory -ObjectType LUN -ObjectId '1' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)

    .EXAMPLE
        PS> Get-DMPerformanceHistory -ObjectType Controller -ObjectId '0A','0B' -Metric TotalIOPS,AvgLatencyMs -StartTime (Get-Date).AddHours(-6) -EndTime (Get-Date) -KeepReportTask

    .NOTES
        Filename: Get-DMPerformanceHistory.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('LUN', 'Controller', 'StoragePool', 'Disk', 'Host', 'System', 'FCPort', 'EthernetPort')]
        [string]$ObjectType,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ObjectId,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-DMPerformanceIndicatorMap).Keys | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [ValidateScript({
                $validNames = (Get-DMPerformanceIndicatorMap).Keys
                foreach ($metricName in $_) {
                    if ($metricName -notin $validNames) {
                        throw "Unknown performance metric '$metricName'. Valid metrics: $($validNames -join ', ')"
                    }
                }
                return $true
            })]
        [string[]]$Metric,

        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $true)]
        [datetime]$EndTime,

        [ValidateSet('Avg', 'Max')]
        [string]$ComputeMode = 'Avg',

        [ValidateRange(1, 86400)]
        [int]$TimeoutSec = 120,

        [switch]$KeepReportTask
    )

    begin {
        $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
        $metricNames = @(if ($PSBoundParameters.ContainsKey('Metric') -and $Metric) { $Metric } else { $script:DMDefaultPerformanceMetrics })
        $collectedIds = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($id in $ObjectId) {
            $collectedIds.Add($id)
        }
    }

    end {
        $samples = [System.Collections.ArrayList]::new()
        if ($collectedIds.Count -eq 0) {
            return $samples
        }

        $taskName = "DMPerfHistory_$([guid]::NewGuid().ToString('N'))"
        $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "$taskName.zip"
        $task = $null
        $log = $null

        try {
            $task = New-DMPerformanceReportTask -WebSession $session -Name $taskName -TimeSegment 'Customer' `
                -StartTime $StartTime -EndTime $EndTime -Format 'CSV' -RetentionNumber 1 `
                -ObjectType $ObjectType -ObjectId @($collectedIds) -Metric $metricNames -ComputeMode $ComputeMode -Confirm:$false

            if ($null -eq $task) {
                throw 'Get-DMPerformanceHistory: failed to create the underlying report task.'
            }

            $log = Invoke-DMPerformanceReportTask -WebSession $session -Id $task.Id -TimeoutSec $TimeoutSec -Confirm:$false

            if ($null -eq $log) {
                throw 'Get-DMPerformanceHistory: report task did not produce an export log.'
            }

            Save-DMPerformanceReportFile -WebSession $session -LogId $log.LogId -Path $tempZip -Force | Out-Null

            $rows = Import-DMPerformanceReportCsv -ZipPath $tempZip
            $metricCount = $metricNames.Count

            foreach ($row in $rows) {
                $propNames = @($row.PSObject.Properties.Name | Where-Object { $_ -ne 'SourceFile' })
                if ($propNames.Count -lt $metricCount) {
                    Write-Warning "Get-DMPerformanceHistory: skipping a CSV row with fewer columns ($($propNames.Count)) than requested metrics ($metricCount)."
                    continue
                }

                $startIdx = $propNames.Count - $metricCount
                $metricPropNames = $propNames[$startIdx..($propNames.Count - 1)]
                $leadingPropNames = if ($startIdx -gt 0) { $propNames[0..($startIdx - 1)] } else { @() }

                $objectIdProp = $leadingPropNames | Where-Object { $_ -match '(?i)object.?id|^id$' } | Select-Object -First 1
                $timeProp = $leadingPropNames | Where-Object { $_ -match '(?i)time|date' } | Select-Object -First 1

                $rowObjectId = if ($objectIdProp) { $row.$objectIdProp } else { $null }

                $timestamp = [datetime]::MinValue
                if ($timeProp) {
                    $rawTime = $row.$timeProp
                    if ($rawTime -match '^\d+$') {
                        $timestamp = [DateTimeOffset]::FromUnixTimeSeconds([long]$rawTime).UtcDateTime
                    }
                    else {
                        $parsed = [datetime]::MinValue
                        if ([datetime]::TryParse($rawTime, [ref]$parsed)) {
                            $timestamp = $parsed
                        }
                    }
                }

                $metrics = [ordered]@{}
                for ($i = 0; $i -lt $metricCount; $i++) {
                    $rawValue = $row.($metricPropNames[$i])
                    $metrics[$metricNames[$i]] = if ($null -ne $rawValue -and "$rawValue" -ne '') { [double]$rawValue } else { $null }
                }

                $sample = New-DMPerformanceSample -ObjectType $ObjectType -ObjectId $rowObjectId -Timestamp $timestamp `
                    -Metrics $metrics -Session $session

                [void]$samples.Add($sample)
            }

            return $samples
        }
        finally {
            if (-not $KeepReportTask) {
                if ($log) {
                    try {
                        Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "pms/report_task/task_log?log_id=$($log.LogId)" -ApiV2 | Out-Null
                    }
                    catch {
                        Write-Warning "Get-DMPerformanceHistory: failed to remove export log $($log.LogId): $_"
                    }
                }
                if ($task) {
                    try {
                        Remove-DMPerformanceReportTask -WebSession $session -Id $task.Id -Confirm:$false | Out-Null
                    }
                    catch {
                        Write-Warning "Get-DMPerformanceHistory: failed to remove report task $($task.Id): $_"
                    }
                }
            }
            if (Test-Path -LiteralPath $tempZip) {
                Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
