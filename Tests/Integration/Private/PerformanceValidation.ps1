# Performance/capacity integrity validation (Phases 1-5 of the performance implementation).
#
# Continuation of the getter-integrity harness: reuses the runner's session, result plumbing
# (Add-ValidationResult / Add-SkippedResult / Invoke-MutationStep), ownership registry and
# reporting. Everything here is opt-in: it requires one of the -Include* runner switches AND
# the Performance section of IntegrityValidationConfig.psd1. Without both gates the dispatcher
# returns before doing anything, so existing validation runs are unchanged.
#
# Safety model (see .archived-commands/PerformanceIntegrityTests-Plan.md):
# - Phases 1-3 are read-only by construction; a trace audit proves no mutating REST calls ran.
# - Phases 4-5 create report tasks only (metadata, never storage objects). Every created task
#   is named with the run prefix + a per-run token, ID-captured immediately, registered in the
#   ownership registry AND the performance cleanup registry, and deleted by captured ID only.
# - A baseline snapshot of pre-existing report-task IDs is taken before anything is created;
#   cleanup refuses to touch any baseline ID even if ownership were ever mis-registered.

function Invoke-PerformanceValidation {
    $anyRequested = $IncludePerformance -or $IncludePerformanceHistory -or $IncludeCapacityHistory -or $IncludeExcelPerformance
    if (-not $anyRequested) {
        # No performance switches: keep non-performance runs byte-for-byte unchanged.
        return
    }

    $perfConfig = $configuration['Performance']
    if (-not $perfConfig -or -not $perfConfig.Enabled) {
        Add-SkippedResult -Name @('Performance validation') -Status 'NotConfigured' `
            -Reason 'Add the Performance section with Enabled = $true to IntegrityValidationConfig.psd1 to acknowledge performance integrity checks.'
        return
    }

    $script:performanceConfig = $perfConfig
    $script:perfRunToken = [guid]::NewGuid().ToString('N').Substring(0, 6)
    $script:performanceReportTaskGateReason = if (-not $perfConfig.AllowReportTaskCreation) {
        'Set Performance.AllowReportTaskCreation = $true in IntegrityValidationConfig.psd1 to acknowledge creation and cleanup of test-owned report tasks.'
    }
    else {
        $null
    }

    Write-Host "Performance validation run token: $($script:perfRunToken). Report tasks created by this run are named '$($configuration.NamePrefix)_p$($script:perfRunToken)_<case>'."

    if (-not (Test-Path -LiteralPath $PerformanceOutputPath)) {
        $null = New-Item -Path $PerformanceOutputPath -ItemType Directory -Force
    }
    Write-Host "Performance output directory: $PerformanceOutputPath"

    # Route REST tracing into the performance sink so the read-only audit can inspect what ran.
    # Invoke-MutationValidation re-points the sink to $mutationRequests itself when mutating
    # tests are requested, so this does not interfere with the existing mutation trace log.
    Enable-DMValidationRequestTrace -Sink $performanceRequests

    try {
        if ($IncludePerformance) {
            if ($script:PerformanceRealtimeWorkflow) {
                . $script:PerformanceRealtimeWorkflow
            }
            else {
                Add-SkippedResult -Name @('Performance:Realtime') -Status 'Blocked' -Reason 'Workflows\PerformanceRealtime.ps1 is not present.'
            }
        }
        else {
            Add-SkippedResult -Name @('Performance:Realtime') -Status 'NotRequested' -Reason 'Call the runner with -IncludePerformance to run realtime performance read checks.'
        }

        if ($IncludeExcelPerformance) {
            if ($script:PerformanceExcelWorkflow) {
                . $script:PerformanceExcelWorkflow
            }
            else {
                Add-SkippedResult -Name @('Performance:Excel') -Status 'Blocked' -Reason 'Workflows\PerformanceExcel.ps1 is not present.'
            }
        }

        if ($IncludePerformanceHistory) {
            if ($script:PerformanceReportTaskWorkflow) {
                . $script:PerformanceReportTaskWorkflow
            }
            else {
                Add-SkippedResult -Name @('Performance:ReportTask') -Status 'Blocked' -Reason 'Workflows\PerformanceReportTask.ps1 is not present.'
            }
        }

        if ($IncludePerformance -or $IncludeCapacityHistory) {
            if ($script:PerformanceCapacityWorkflow) {
                . $script:PerformanceCapacityWorkflow
            }
            else {
                Add-SkippedResult -Name @('Performance:Capacity') -Status 'Blocked' -Reason 'Workflows\PerformanceCapacity.ps1 is not present.'
            }
        }
    }
    finally {
        # Workflows drain their own entries per case; this catches anything they could not.
        Invoke-PerformanceCleanup
        Write-PerformanceArtifacts
    }
}

function Register-PerformanceCleanup {
    <#
    .SYNOPSIS
        Records a test-created object in the performance cleanup registry.

    .DESCRIPTION
        Must be called immediately after the create call returns, with the ID captured from the
        create response. Entries are drained by Invoke-PerformanceCleanup ordered by
        CleanupOrder (report logs before report tasks before local files), LIFO within the same
        order. Cleanup is data-driven from the entry's own captured ID (no scriptblocks), so the
        runner-finally backstop can still drain entries after an interrupt when the workflow's
        local variables are long out of scope. Array-side kinds always go through the
        ownership + baseline guards.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('ReportLog', 'ReportTask', 'LocalFile')][string]$Kind,
        [Parameter(Mandatory)][string]$Id,
        [string]$Name = '',
        [string]$CleanupCommand = '',
        # ReportTask only: enumerate and delete the owned task's export logs (by the captured
        # task ID) before deleting the task itself. Used for -KeepReportTask leftovers whose
        # log IDs were never returned to the caller.
        [switch]$RemoveLogsFirst
    )

    $order = switch ($Kind) {
        'ReportLog' { 10 }
        'ReportTask' { 20 }
        'LocalFile' { 30 }
    }

    $entry = [pscustomobject]@{
        ObjectKind      = $Kind
        ObjectId        = $Id
        ObjectName      = $Name
        CreatedAt       = (Get-Date).ToString('o')
        CleanupCommand  = $CleanupCommand
        CleanupOrder    = $order
        Sequence        = $performanceCleanupRegistry.Count
        RemoveLogsFirst = [bool]$RemoveLogsFirst
        Completed       = $false
        Failed          = $false
        Kept            = $false
    }
    $performanceCleanupRegistry.Add($entry)
    Write-Host "Registered performance cleanup: [$Kind] Id=$Id$(if ($Name) { " Name=$Name" })"
    return $entry
}

function Invoke-PerformanceCleanup {
    <#
    .SYNOPSIS
        Drains pending performance cleanup entries (all of them, or just the ones passed in).
    #>
    param([object[]]$Entries)

    $pending = @($(if ($Entries) { $Entries } else { $performanceCleanupRegistry }) |
            Where-Object { $_ -and -not $_.Completed -and -not $_.Failed })
    if ($pending.Count -eq 0) {
        return
    }

    $pending = @($pending | Sort-Object -Property CleanupOrder, @{ Expression = 'Sequence'; Descending = $true })

    foreach ($entry in $pending) {
        if ($KeepCreatedReportTasks -and $entry.ObjectKind -in @('ReportTask', 'ReportLog')) {
            $entry.Kept = $true
            $entry.Completed = $true
            Write-Host "-KeepCreatedReportTasks: leaving [$($entry.ObjectKind)] Id=$($entry.ObjectId) Name=$($entry.ObjectName) in place. Manual cleanup: $($entry.CleanupCommand)"
            continue
        }

        try {
            switch ($entry.ObjectKind) {
                'ReportLog' {
                    Remove-OwnedPerformanceReportLog -LogId $entry.ObjectId
                }
                'ReportTask' {
                    if ($entry.RemoveLogsFirst) {
                        try {
                            $taskLogs = @(Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "pms/report_task/task_log?task_id=$($entry.ObjectId)" -ApiV2 | Select-DMResponseData)
                            foreach ($taskLog in $taskLogs) {
                                if ("$($taskLog.id)" -ne '') {
                                    Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "pms/report_task/task_log?log_id=$($taskLog.id)" -ApiV2 | Out-Null
                                }
                            }
                        }
                        catch {
                            Write-Warning "Could not enumerate/remove export logs of test-owned task '$($entry.ObjectId)': $($_.Exception.Message)"
                        }
                    }
                    Remove-OwnedPerformanceReportTask -Id $entry.ObjectId -Name $entry.ObjectName
                }
                'LocalFile' {
                    if (Test-Path -LiteralPath $entry.ObjectId) {
                        Remove-Item -LiteralPath $entry.ObjectId -Force
                    }
                }
            }
            $entry.Completed = $true
        }
        catch {
            $entry.Failed = $true
            $checks.Add([pscustomobject]@{
                Name         = "Cleanup:$($entry.ObjectKind):$($entry.ObjectId)"
                Category     = 'Mutation'
                Status       = 'Failed'
                DurationMs   = $null
                Count        = 0
                ExpectedType = $null
                ActualTypes  = @()
                Error        = $_.Exception.Message
            })
            Write-Warning "Performance cleanup FAILED for [$($entry.ObjectKind)] Id=$($entry.ObjectId) Name=$($entry.ObjectName): $($_.Exception.Message)"
            if ($entry.CleanupCommand) {
                Write-Warning "  Manual cleanup command: $($entry.CleanupCommand)"
            }
        }
    }
}

function Invoke-PerformanceCleanupBackstop {
    <#
    .SYNOPSIS
        Runner-finally backstop: drains anything still registered and reports leftovers loudly.

    .DESCRIPTION
        Safe to call unconditionally (no-op when the performance section never ran or already
        cleaned up everything). This closes the interrupt gap: even if a workflow was aborted
        between create and its own finally, the registered entry is drained here.
    #>
    if (-not (Get-Variable -Name performanceCleanupRegistry -ErrorAction SilentlyContinue) -or $null -eq $performanceCleanupRegistry) {
        return
    }

    $pending = @($performanceCleanupRegistry | Where-Object { -not $_.Completed -and -not $_.Failed })
    if ($pending.Count -gt 0) {
        Write-Warning "Performance cleanup backstop: $($pending.Count) test-created object(s) still registered; draining now."
        Invoke-PerformanceCleanup
    }

    $leftovers = @($performanceCleanupRegistry | Where-Object { $_.Failed -or ($_.Kept -and $_.ObjectKind -ne 'LocalFile') })
    if ($leftovers.Count -gt 0) {
        Write-Warning 'The following test-created objects were NOT removed:'
        foreach ($entry in $leftovers) {
            $state = if ($entry.Failed) { 'cleanup failed' } else { 'kept on request' }
            Write-Warning ("  [{0}] Id={1} Name={2} ({3}). Manual cleanup: {4}" -f $entry.ObjectKind, $entry.ObjectId, $entry.ObjectName, $state, $entry.CleanupCommand)
        }
    }

    # The run-owned output directory is created by this run; remove it once its
    # registered files are drained so repeated runs do not accumulate empty
    # dm_integrity_perf_* directories under the temp path. Non-empty directories
    # are left alone (they may hold files kept on request).
    if ($PerformanceOutputPath -and (Test-Path -LiteralPath $PerformanceOutputPath)) {
        if (@(Get-ChildItem -LiteralPath $PerformanceOutputPath -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item -LiteralPath $PerformanceOutputPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-PerformanceSampleMetricName {
    param([Parameter(Mandatory)][object]$Sample)

    $reserved = @('ObjectType', 'ObjectId', 'Timestamp', 'RawIndicators', 'RawValues', 'Session', 'ObjectName')
    return @($Sample.PSObject.Properties.Name | Where-Object { $_ -notin $reserved })
}

function Assert-PerformanceSample {
    <#
    .SYNOPSIS
        Shape assertions for an OceanStor.PerformanceSample; throws with a specific message on
        the first violation. Metric values are asserted numeric-or-null (never required non-null,
        because arrays legitimately return no data while monitoring is disabled).
    #>
    param(
        [Parameter(Mandatory)][object]$Sample,
        [Parameter(Mandatory)][string]$ExpectedObjectType,
        [string[]]$AllowedObjectIds,
        [string[]]$RequiredMetricNames,
        [string[]]$ExactMetricNames,
        [switch]$AllowMinValueTimestamp,
        [switch]$AllowTextMetrics
    )

    if ($Sample.PSObject.TypeNames[0] -ne 'OceanStor.PerformanceSample') {
        throw "Expected an OceanStor.PerformanceSample, got '$($Sample.PSObject.TypeNames[0])'."
    }
    if ("$($Sample.ObjectType)" -ne $ExpectedObjectType) {
        throw "Expected ObjectType '$ExpectedObjectType', got '$($Sample.ObjectType)'."
    }
    if ($AllowedObjectIds -and "$($Sample.ObjectId)" -notin $AllowedObjectIds) {
        throw "Sample ObjectId '$($Sample.ObjectId)' is not one of the requested IDs ($($AllowedObjectIds -join ', '))."
    }

    $isMinValue = $Sample.Timestamp -eq [datetime]::MinValue
    if (-not ($AllowMinValueTimestamp -and $isMinValue)) {
        if ($Sample.Timestamp -lt [datetime]'2020-01-01' -or $Sample.Timestamp -gt (Get-Date).AddDays(1)) {
            throw "Sample timestamp '$($Sample.Timestamp)' is outside the sane range (2020-01-01 .. now+1d)."
        }
    }

    $metricNames = Get-PerformanceSampleMetricName -Sample $Sample
    foreach ($metricName in $metricNames) {
        $value = $Sample.$metricName
        if ($null -eq $value) {
            continue
        }
        if ($value -is [double] -or $value -is [int] -or $value -is [long]) {
            continue
        }
        # Capacity-history samples may legitimately carry text columns (parsed by CSV header);
        # realtime samples must be strictly numeric-or-null.
        if (-not $AllowTextMetrics) {
            throw "Metric '$metricName' has a non-numeric value '$value' ($($value.GetType().Name))."
        }
        if ($value -isnot [string]) {
            throw "Metric '$metricName' has a value of unexpected type $($value.GetType().Name)."
        }
    }

    if ($RequiredMetricNames) {
        foreach ($required in $RequiredMetricNames) {
            if ($required -notin $metricNames) {
                throw "Expected metric property '$required' is missing from the sample (present: $($metricNames -join ', '))."
            }
        }
    }
    if ($ExactMetricNames) {
        $unexpected = @($metricNames | Where-Object { $_ -notin $ExactMetricNames })
        $missing = @($ExactMetricNames | Where-Object { $_ -notin $metricNames })
        if ($unexpected.Count -gt 0 -or $missing.Count -gt 0) {
            throw "Sample metric set mismatch. Missing: [$($missing -join ', ')]; unexpected: [$($unexpected -join ', ')]."
        }
    }
}

function Assert-PerformanceTraceReadOnly {
    <#
    .SYNOPSIS
        Proves a read-only section issued no mutating REST calls: no DELETE/PUT/PATCH, and no
        POST other than the allowed query-style resources (performance_data by default).
    #>
    param(
        [Parameter(Mandatory)][int]$FromIndex,
        [string[]]$AllowedPostResources = @('performance_data')
    )

    $entries = @($performanceRequests | Select-Object -Skip $FromIndex)
    $violations = @(foreach ($entry in $entries) {
            $method = "$($entry.Method)".ToUpperInvariant()
            if ($method -in @('DELETE', 'PUT', 'PATCH')) {
                "$method $($entry.Resource)"
            }
            elseif ($method -eq 'POST') {
                $allowed = @($AllowedPostResources | Where-Object { "$($entry.Resource)" -like "$_*" })
                if ($allowed.Count -eq 0) {
                    "POST $($entry.Resource)"
                }
            }
        })

    if ($violations.Count -gt 0) {
        throw "Read-only trace audit found mutating REST calls: $((@($violations) | Select-Object -First 5) -join '; ')"
    }

    return [pscustomobject]@{ AuditedRequests = $entries.Count; Violations = 0 }
}

function Get-PerformanceReportTaskSnapshot {
    return @(Get-DMPerformanceReportTask -WebSession $session)
}

function Initialize-PerformanceReportTaskBaseline {
    <#
    .SYNOPSIS
        Captures the IDs of all report tasks that existed before this run created anything.
        Doubles as the pms-v2-API availability probe (throws when the API is unavailable).
        Idempotent: the baseline is only captured once per run.
    #>
    $tasks = Get-PerformanceReportTaskSnapshot
    if (-not $script:performanceReportTaskBaseline) {
        $script:performanceReportTaskBaseline = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($task in $tasks) {
            [void]$script:performanceReportTaskBaseline.Add("$($task.Id)")
        }
        Write-Host "Report-task baseline captured: $(@($tasks).Count) pre-existing task(s) are protected from cleanup."
    }
    return $tasks
}

function Assert-NotBaselinePerformanceReportTask {
    param([Parameter(Mandatory)][string]$Id)

    if ($script:performanceReportTaskBaseline -and $script:performanceReportTaskBaseline.Contains($Id)) {
        throw "Safety guard refused to touch report task '$Id' because it existed before this validation run."
    }
}

function Remove-OwnedPerformanceReportTask {
    <#
    .SYNOPSIS
        Deletes a report task by captured ID, but only when it is registered as test-owned AND
        is not part of the pre-run baseline.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Name = ''
    )

    Assert-TestOwnedResource -Kind ReportTask -Identity $Id
    Assert-NotBaselinePerformanceReportTask -Id $Id
    Remove-DMPerformanceReportTask -WebSession $session -Id $Id -Confirm:$false | Out-Null
    Complete-TestOwnedResource -Kind ReportTask -Identity $Id
    Write-Host "Removed test-owned report task Id=$Id$(if ($Name) { " Name=$Name" })"
}

function Remove-OwnedPerformanceReportLog {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param([Parameter(Mandatory)][string]$LogId)

    Assert-TestOwnedResource -Kind ReportLog -Identity $LogId
    Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "pms/report_task/task_log?log_id=$LogId" -ApiV2 | Out-Null
    Complete-TestOwnedResource -Kind ReportLog -Identity $LogId
    Write-Host "Removed test-owned report export log Id=$LogId"
}

function Add-PerformanceArtifact {
    <#
    .SYNOPSIS
        Records a live-confirmation artifact (CSV headers, NAS metric applicability, ...) that
        is dumped to Reports\performance-integrity-artifacts.json at the end of the run.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowNull()][object]$Value
    )

    $script:performanceArtifacts[$Name] = $Value
}

function Write-PerformanceArtifacts {
    $registryDump = @($performanceCleanupRegistry | ForEach-Object {
            [pscustomobject]@{
                ObjectKind     = $_.ObjectKind
                ObjectId       = $_.ObjectId
                ObjectName     = $_.ObjectName
                CreatedAt      = $_.CreatedAt
                CleanupCommand = $_.CleanupCommand
                CleanupOrder   = $_.CleanupOrder
                Completed      = $_.Completed
                Failed         = $_.Failed
                Kept           = $_.Kept
            }
        })

    if ($script:performanceArtifacts.Count -eq 0 -and $registryDump.Count -eq 0) {
        return
    }

    $artifactPath = Join-Path (Split-Path -Path $ReportPath -Parent) 'performance-integrity-artifacts.json'
    $artifactDirectory = Split-Path -Path $artifactPath -Parent
    if ($artifactDirectory -and -not (Test-Path -LiteralPath $artifactDirectory)) {
        $null = New-Item -Path $artifactDirectory -ItemType Directory -Force
    }

    [pscustomobject]@{
        GeneratedAt     = (Get-Date).ToString('o')
        Hostname        = $Hostname
        RunId           = $runId
        PerfRunToken    = $script:perfRunToken
        Artifacts       = $script:performanceArtifacts
        CleanupRegistry = $registryDump
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $artifactPath

    Write-Host "Performance artifacts written to $artifactPath"
}

# Workflow scriptblocks (each file defines a $script:Performance*Workflow scriptblock). Files
# are optional so the phases can ship incrementally; the dispatcher reports a missing file as
# an explicit Blocked skip instead of crashing.
foreach ($performanceWorkflowFile in @('PerformanceRealtime.ps1', 'PerformanceExcel.ps1', 'PerformanceReportTask.ps1', 'PerformanceCapacity.ps1')) {
    $performanceWorkflowPath = Join-Path $PSScriptRoot "Workflows\$performanceWorkflowFile"
    if (Test-Path -LiteralPath $performanceWorkflowPath) {
        . $performanceWorkflowPath
    }
}
