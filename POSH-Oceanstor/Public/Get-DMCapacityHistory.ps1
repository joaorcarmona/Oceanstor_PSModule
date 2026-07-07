function Get-DMCapacityHistory {
    <#
    .SYNOPSIS
        Retrieves historical capacity samples for OceanStor objects.

    .DESCRIPTION
        Capacity history is only exposed by the array through the pms/report_task workflow, the
        same engine Get-DMPerformanceHistory uses: create a Customer-time-segment report task
        (report_type 'capacity', no performance indicators), run it, wait for the export,
        download the zip, and parse the CSV inside.

        This cmdlet is a convenience wrapper around that pipeline (New-DMPerformanceReportTask
        -ReportType Capacity, Invoke-DMPerformanceReportTask, Save-DMPerformanceReportFile,
        Import-DMPerformanceReportCsv) for callers who just want capacity-over-time objects for
        a time range. The report task and its export log are removed automatically afterwards
        unless -KeepReportTask is specified.

        The capacity CSV column layout has not been confirmed against a live array and capacity
        reports carry no caller-authored indicator list to map columns against, so rows are
        parsed by header: a column whose name looks object-ID-like becomes ObjectId, a
        time/date-like column becomes Timestamp, and every remaining column is preserved as a
        property under its own CSV header name (numeric-looking values are converted to double,
        anything else is kept as-is).

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER ObjectType
        The type of object to retrieve capacity history for. Only System and StoragePool carry
        capacity reports.

    .PARAMETER ObjectId
        One or more object IDs to retrieve capacity history for. Pipeline-able.

    .PARAMETER StartTime
        Window start.

    .PARAMETER EndTime
        Window end.

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
        PS> Get-DMCapacityHistory -ObjectType StoragePool -ObjectId '0' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)

    .EXAMPLE
        PS> Get-DMCapacityHistory -ObjectType System -ObjectId '1' -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -KeepReportTask

    .NOTES
        Filename: Get-DMCapacityHistory.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('System', 'StoragePool')]
        [string]$ObjectType,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ObjectId,

        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $true)]
        [datetime]$EndTime,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSec = 120,

        [switch]$KeepReportTask
    )

    begin {
        $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
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

        # 13-char prefix + 18 guid chars = 31, the real pms/report_task name cap
        # (the documented 32 is off by one on live arrays).
        $taskName = "DMCapHistory_$([guid]::NewGuid().ToString('N').Substring(0, 18))"
        $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "$taskName.zip"
        $task = $null
        $log = $null

        try {
            $task = New-DMPerformanceReportTask -WebSession $session -Name $taskName -ReportType Capacity `
                -TimeSegment 'Customer' -StartTime $StartTime -EndTime $EndTime -Format 'CSV' -RetentionNumber 1 `
                -ObjectType $ObjectType -ObjectId @($collectedIds) -Confirm:$false

            if ($null -eq $task) {
                throw 'Get-DMCapacityHistory: failed to create the underlying report task.'
            }

            $log = Invoke-DMPerformanceReportTask -WebSession $session -Id $task.Id -TimeoutSec $TimeoutSec -Confirm:$false

            if ($null -eq $log) {
                throw 'Get-DMCapacityHistory: report task did not produce an export log.'
            }

            Save-DMPerformanceReportFile -WebSession $session -LogId $log.LogId -TaskId $task.Id -Path $tempZip -Force | Out-Null

            $rows = Import-DMPerformanceReportCsv -ZipPath $tempZip

            # Live arrays export long-format CSVs -- one row per object/metric/timestamp
            # with headers 'Object Type,Object Instance,Statistical Metric,Value,Time,
            # Object Type ID,Object Instance ID,Statistical Metric ID' (confirmed on
            # Dorado V600R005C27; capacity metric IDs observed: 90001 Total capacity(MB),
            # 90002 Used capacity(MB), 90004 Capacity usage(%)). Pivot into one sample
            # per object/timestamp keyed by the metric display name.
            $firstRow = $rows | Select-Object -First 1
            $firstRowProps = if ($firstRow) { @($firstRow.PSObject.Properties.Name) } else { @() }
            if (($firstRowProps -contains 'Statistical Metric') -and ($firstRowProps -contains 'Value')) {
                foreach ($group in ($rows | Group-Object -Property 'Object Instance ID', 'Time')) {
                    $groupRows = @($group.Group)
                    $firstOfGroup = $groupRows[0]

                    # Times arrive as '2026-07-06 00:00:00 DST'; drop the trailing zone token.
                    $timestamp = [datetime]::MinValue
                    $rawTime = "$($firstOfGroup.Time)" -replace '\s+[A-Z]{2,5}$', ''
                    $parsed = [datetime]::MinValue
                    if ([datetime]::TryParse($rawTime, [ref]$parsed)) { $timestamp = $parsed }

                    $metrics = [ordered]@{}
                    foreach ($entry in $groupRows) {
                        $rawValue = $entry.Value
                        $numeric = 0.0
                        $metrics["$($entry.'Statistical Metric')"] = if ($null -ne $rawValue -and "$rawValue" -ne '' -and [double]::TryParse("$rawValue", [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$numeric)) {
                            $numeric
                        }
                        else {
                            "$rawValue"
                        }
                    }

                    $sample = New-DMPerformanceSample -ObjectType $ObjectType -ObjectId "$($firstOfGroup.'Object Instance ID')" -Timestamp $timestamp `
                        -Metrics $metrics -Session $session
                    [void]$samples.Add($sample)
                }

                return $samples
            }

            # Wide-format fallback (one column per metric), kept for firmware whose
            # exports differ from the long format observed live.
            foreach ($row in $rows) {
                $propNames = @($row.PSObject.Properties.Name | Where-Object { $_ -ne 'SourceFile' })
                if ($propNames.Count -eq 0) { continue }

                $objectIdProp = $propNames | Where-Object { $_ -match '(?i)object.?id|^id$' } | Select-Object -First 1
                $timeProp = $propNames | Where-Object { $_ -match '(?i)time|date' } | Select-Object -First 1

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
                foreach ($col in $propNames) {
                    if ($col -eq $objectIdProp -or $col -eq $timeProp) { continue }
                    $rawValue = $row.$col
                    if ($null -eq $rawValue -or "$rawValue" -eq '') {
                        $metrics[$col] = $null
                        continue
                    }
                    $numeric = 0.0
                    $metrics[$col] = if ([double]::TryParse("$rawValue", [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$numeric)) {
                        $numeric
                    }
                    else {
                        "$rawValue"
                    }
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
                        Write-Warning "Get-DMCapacityHistory: failed to remove export log $($log.LogId): $_"
                    }
                }
                if ($task) {
                    try {
                        Remove-DMPerformanceReportTask -WebSession $session -Id $task.Id -Confirm:$false | Out-Null
                    }
                    catch {
                        Write-Warning "Get-DMCapacityHistory: failed to remove report task $($task.Id): $_"
                    }
                }
            }
            if (Test-Path -LiteralPath $tempZip) {
                Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
