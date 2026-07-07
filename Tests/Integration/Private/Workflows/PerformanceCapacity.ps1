# Phase 5 (capacity history + NAS/FileSystem performance + corrected report-task body
# acceptance) of the performance integrity validation.
#
# The NAS/FileSystem realtime check is read-only and runs under -IncludePerformance. The
# capacity-history checks and the body-acceptance smoke run under -IncludeCapacityHistory and
# create test-owned report tasks only, with the same ownership/baseline/captured-ID safety
# rails as the Phase 4 workflow. No storage object is ever created, modified or deleted.

$script:PerformanceCapacityWorkflow = {
    # =========================================================================================
    # NAS / FileSystem realtime performance (read-only; gate: -IncludePerformance)
    # =========================================================================================
    if ($IncludePerformance) {
        $nasTraceStart = $performanceRequests.Count
        $nasFileSystems = @(Get-DMFileSystem -WebSession $session | Select-Object -First 1)
        if ($nasFileSystems.Count -eq 0) {
            Add-SkippedResult -Name 'Get-DMFileSystemPerformance' -Status 'NoData' -Category 'PerformanceRead' -Reason 'No file systems exist on the array.'
        }
        else {
            $nasFileSystemIds = @($nasFileSystems | ForEach-Object { "$($_.Id)" })
            Add-ValidationResult -Name 'Get-DMFileSystemPerformance' -Category 'PerformanceRead' -Action {
                $nasSamples = @($nasFileSystems | Get-DMFileSystemPerformance -WebSession $session)
                if ($nasSamples.Count -eq 0) {
                    throw "Get-DMFileSystemPerformance returned no samples for file system(s) $($nasFileSystemIds -join ', ')."
                }
                foreach ($nasSample in $nasSamples) {
                    Assert-PerformanceSample -Sample $nasSample -ExpectedObjectType FileSystem -AllowedObjectIds $nasFileSystemIds `
                        -RequiredMetricNames @('Ops', 'ReadOps', 'WriteOps', 'AvgReadOpsResponseTimeUs', 'AvgWriteOpsResponseTimeUs')
                }
                # Live-confirmation artifact: which NAS indicators actually return data (settles
                # the block-vs-NAS bandwidth indicator and the us-vs-ms response-time questions).
                $nasMetricReport = [ordered]@{}
                foreach ($nasMetricName in (Get-PerformanceSampleMetricName -Sample $nasSamples[0])) {
                    $nasMetricReport[$nasMetricName] = $nasSamples[0].$nasMetricName
                }
                Add-PerformanceArtifact -Name 'NasMetricValues' -Value $nasMetricReport
                Write-Host "NAS metric values (live confirmation): $(@($nasMetricReport.Keys | ForEach-Object { "$_=$($nasMetricReport[$_])" }) -join '; ')"
                $nasSamples
            } | Out-Null

            Add-ValidationResult -Name 'Performance:TraceAudit:FileSystem' -Category 'PerformanceRead' -Action {
                Assert-PerformanceTraceReadOnly -FromIndex $nasTraceStart
            } | Out-Null
        }
    }

    # =========================================================================================
    # Capacity history + body acceptance (gate: -IncludeCapacityHistory + report-task ack)
    # =========================================================================================
    if (-not $IncludeCapacityHistory) {
        return
    }

    $capacityCheckNames = @(
        'Get-DMCapacityHistory:StoragePool', 'Verify:Get-DMCapacityHistory:StoragePool:TaskCleanup', 'Verify:Get-DMCapacityHistory:StoragePool:ReportType',
        'Get-DMCapacityHistory:System', 'Verify:Get-DMCapacityHistory:System:TaskCleanup', 'Verify:Get-DMCapacityHistory:System:ReportType',
        'Get-DMCapacityHistory:KeepReportTask', 'Verify:Get-DMCapacityHistory:KeepReportTask',
        'New-DMPerformanceReportTask:AcceptPerformanceBody', 'New-DMPerformanceReportTask:AcceptCapacityBody'
    )

    if ($script:performanceReportTaskGateReason) {
        Add-SkippedResult -Name $capacityCheckNames -Status 'NotConfigured' -Reason $script:performanceReportTaskGateReason
        return
    }

    $capacityBaselineTasks = $null
    try {
        $capacityBaselineTasks = @(Initialize-PerformanceReportTaskBaseline)
    }
    catch {
        Add-SkippedResult -Name $capacityCheckNames -Status 'Blocked' -Reason "The pms/report_task API probe failed (firmware may not expose the v2 pms interface): $($_.Exception.Message)"
        return
    }

    # Read-only capacity targets.
    $capacitySystemObject = @(Get-DMSystem -WebSession $session)[0]
    $capacitySystemId = if ($capacitySystemObject -and $capacitySystemObject.PSObject.Properties['Id'] -and "$($capacitySystemObject.Id)" -ne '') {
        "$($capacitySystemObject.Id)"
    }
    else {
        '0'
    }
    $capacityPool = @(Get-DMstoragePool -WebSession $session | Select-Object -First 1)

    $capacityTargets = [System.Collections.Generic.List[object]]::new()
    if ($capacityPool.Count -gt 0) {
        $capacityTargets.Add(@{ ObjectType = 'StoragePool'; ObjectId = "$($capacityPool[0].Id)" })
    }
    else {
        Add-SkippedResult -Name @('Get-DMCapacityHistory:StoragePool', 'Verify:Get-DMCapacityHistory:StoragePool:TaskCleanup', 'Verify:Get-DMCapacityHistory:StoragePool:ReportType') `
            -Status 'NoData' -Reason 'No storage pools exist on the array.'
    }
    $capacityTargets.Add(@{ ObjectType = 'System'; ObjectId = $capacitySystemId })

    $capacityStartTime = (Get-Date).AddDays(-1)
    $capacityEndTime = Get-Date

    # Best-effort extraction of content[0].report_type from a traced pms/report_task POST body.
    $extractTracedReportType = {
        param($traceEntry)
        $extracted = $null
        try { $extracted = "$((@($traceEntry.Request['content']))[0]['report_type'])" } catch { $extracted = $null }
        if (-not $extracted) {
            try { $extracted = "$((@($traceEntry.Request.content))[0].report_type)" } catch { $extracted = $null }
        }
        $extracted
    }

    foreach ($capacityTarget in $capacityTargets) {
        $capacityTargetType = $capacityTarget.ObjectType
        $capacityTargetId = $capacityTarget.ObjectId
        $capacityPreTaskIds = @(Get-PerformanceReportTaskSnapshot | ForEach-Object { "$($_.Id)" })
        $capacityTraceStart = $performanceRequests.Count

        Add-ValidationResult -Name "Get-DMCapacityHistory:$capacityTargetType" -Category 'Mutation' -Action {
            $capacityRows = @(Get-DMCapacityHistory -WebSession $session -ObjectType $capacityTargetType -ObjectId $capacityTargetId `
                    -StartTime $capacityStartTime -EndTime $capacityEndTime -TimeoutSec $PerformanceTimeoutSec)
            if ($capacityRows.Count -gt 0) {
                foreach ($capacityRow in $capacityRows) {
                    Assert-PerformanceSample -Sample $capacityRow -ExpectedObjectType $capacityTargetType -AllowMinValueTimestamp -AllowTextMetrics
                }
                $capacityColumns = @(Get-PerformanceSampleMetricName -Sample $capacityRows[0])
                Add-PerformanceArtifact -Name "CapacityCsvColumns:$capacityTargetType" -Value $capacityColumns
                Write-Host "Capacity CSV columns for ${capacityTargetType} (live confirmation): $($capacityColumns -join ' | ')"
            }
            # Zero rows surface as NoData via the harness, not as a failure.
            $capacityRows
        } | Out-Null

        Add-ValidationResult -Name "Verify:Get-DMCapacityHistory:${capacityTargetType}:TaskCleanup" -Category 'MutationRead' -Action {
            $capacityPostTasks = @(Get-PerformanceReportTaskSnapshot)
            $capacityLeftovers = @($capacityPostTasks | Where-Object { "$($_.Id)" -notin $capacityPreTaskIds })
            if ($capacityLeftovers.Count -gt 0) {
                throw "Get-DMCapacityHistory left $($capacityLeftovers.Count) report task(s) behind: $(@($capacityLeftovers | ForEach-Object { "$($_.Name) ($($_.Id))" }) -join ', ')."
            }
            [pscustomobject]@{ CleanedUp = $true }
        } | Out-Null

        Add-ValidationResult -Name "Verify:Get-DMCapacityHistory:${capacityTargetType}:ReportType" -Category 'MutationRead' -Action {
            $capacityPosts = @($performanceRequests | Select-Object -Skip $capacityTraceStart |
                    Where-Object { "$($_.Method)".ToUpperInvariant() -eq 'POST' -and "$($_.Resource)" -like 'pms/report_task*' })
            if ($capacityPosts.Count -eq 0) {
                throw 'No traced POST pms/report_task request was found for the capacity-history call.'
            }
            $capacityReportTypes = @($capacityPosts | ForEach-Object { & $extractTracedReportType $_ })
            Add-PerformanceArtifact -Name "CapacityReportTypeBody:$capacityTargetType" -Value $capacityReportTypes
            $wrongTypes = @($capacityReportTypes | Where-Object { $_ -ne 'capacity' })
            if ($wrongTypes.Count -gt 0) {
                throw "Expected every capacity report-task body to carry report_type 'capacity'; traced values: $($capacityReportTypes -join ', ')."
            }
            [pscustomobject]@{ TracedBodies = $capacityPosts.Count; ReportType = 'capacity' }
        } | Out-Null
    }

    # --- -KeepReportTask behavior, validated with a test-created DMCapHistory_* task ----------
    $keepCapacityTarget = $capacityTargets[0]
    $keepCapacityPreTaskIds = @(Get-PerformanceReportTaskSnapshot | ForEach-Object { "$($_.Id)" })
    $keptCapacityTaskId = $null
    $keptCapacityTaskName = $null
    $keepCapacityRegistryStart = $performanceCleanupRegistry.Count

    try {
        Add-ValidationResult -Name 'Get-DMCapacityHistory:KeepReportTask' -Category 'Mutation' -Action {
            Get-DMCapacityHistory -WebSession $session -ObjectType $keepCapacityTarget.ObjectType -ObjectId $keepCapacityTarget.ObjectId `
                -StartTime $capacityStartTime -EndTime $capacityEndTime -TimeoutSec $PerformanceTimeoutSec -KeepReportTask | Out-Null
            [pscustomobject]@{ Completed = $true }
        } | Out-Null

        $keepCapacityNewTasks = @(Get-PerformanceReportTaskSnapshot | Where-Object { "$($_.Id)" -notin $keepCapacityPreTaskIds })
        $keptCapacityCandidates = @($keepCapacityNewTasks | Where-Object { "$($_.Name)" -like 'DMCapHistory_*' })

        Add-ValidationResult -Name 'Verify:Get-DMCapacityHistory:KeepReportTask' -Category 'MutationRead' -Action {
            if ($keptCapacityCandidates.Count -eq 0) {
                throw '-KeepReportTask did not leave the internally created DMCapHistory_* report task in place.'
            }
            if ($keptCapacityCandidates.Count -gt 1) {
                throw "Expected exactly one new DMCapHistory_* report task, found $($keptCapacityCandidates.Count): $(@($keptCapacityCandidates | ForEach-Object Name) -join ', ')."
            }
            $keptCapacityCandidates
        } | Out-Null

        if ($keptCapacityCandidates.Count -eq 1) {
            $keptCapacityTaskId = "$($keptCapacityCandidates[0].Id)"
            $keptCapacityTaskName = "$($keptCapacityCandidates[0].Name)"
            Register-TestOwnedResource -Kind ReportTask -Identity $keptCapacityTaskId
            # -KeepReportTask also keeps the export log; RemoveLogsFirst sweeps the owned
            # task's logs (queried strictly by the captured task ID) before the task delete.
            Register-PerformanceCleanup -Kind ReportTask -Id $keptCapacityTaskId -Name $keptCapacityTaskName -RemoveLogsFirst `
                -CleanupCommand "Remove-DMPerformanceReportTask -Id '$keptCapacityTaskId' -Confirm:`$false" | Out-Null
        }
    }
    finally {
        Invoke-PerformanceCleanup -Entries @($performanceCleanupRegistry | Select-Object -Skip $keepCapacityRegistryStart)
    }

    # =========================================================================================
    # Corrected report-task body acceptance smoke (the definitive Phase 5 Part 0 live test)
    # =========================================================================================
    $acceptanceTargetType = 'System'
    $acceptanceTargetId = $capacitySystemId
    $acceptanceController = @(Get-DMController -WebSession $session | Select-Object -First 1)
    if ($acceptanceController.Count -gt 0) {
        $acceptanceTargetType = 'Controller'
        $acceptanceTargetId = "$($acceptanceController[0].Id)"
    }
    $acceptanceCapacityType = if ($capacityPool.Count -gt 0) { 'StoragePool' } else { 'System' }
    $acceptanceCapacityId = if ($capacityPool.Count -gt 0) { "$($capacityPool[0].Id)" } else { $capacitySystemId }
    $acceptanceRetention = if ($script:performanceConfig.ReportTaskRetentionNumber) { [int]$script:performanceConfig.ReportTaskRetentionNumber } else { 1 }

    $acceptanceCases = @(
        @{
            CheckName  = 'New-DMPerformanceReportTask:AcceptPerformanceBody'
            TaskName   = New-ReportTaskName -Suffix "p$($script:perfRunToken)_acp"
            ReportType = 'Performance'
            ObjectType = $acceptanceTargetType
            ObjectId   = $acceptanceTargetId
        }
        @{
            CheckName  = 'New-DMPerformanceReportTask:AcceptCapacityBody'
            TaskName   = New-ReportTaskName -Suffix "p$($script:perfRunToken)_acc"
            ReportType = 'Capacity'
            ObjectType = $acceptanceCapacityType
            ObjectId   = $acceptanceCapacityId
        }
    )

    foreach ($acceptanceCase in $acceptanceCases) {
        $acceptanceTaskId = $null
        $acceptanceRegistryStart = $performanceCleanupRegistry.Count
        try {
            $acceptanceCreated = @(Invoke-MutationStep -Name $acceptanceCase.CheckName -ExpectedType 'OceanstorPerformanceReportTask' -Action {
                if (@($capacityBaselineTasks | Where-Object { $_.Name -eq $acceptanceCase.TaskName }).Count -gt 0) {
                    throw "A report task named '$($acceptanceCase.TaskName)' already exists; refusing to claim it as test-owned."
                }
                New-DMPerformanceReportTask -WebSession $session -Name $acceptanceCase.TaskName -ReportType $acceptanceCase.ReportType `
                    -TimeSegment OneDay -Format CSV -RetentionNumber $acceptanceRetention `
                    -ObjectType $acceptanceCase.ObjectType -ObjectId $acceptanceCase.ObjectId -Confirm:$false
            })
            if ($acceptanceCreated.Count -gt 0 -and "$($acceptanceCreated[0].Id)" -ne '') {
                $acceptanceTaskId = "$($acceptanceCreated[0].Id)"
                Register-TestOwnedResource -Kind ReportTask -Identity $acceptanceTaskId
                Register-PerformanceCleanup -Kind ReportTask -Id $acceptanceTaskId -Name $acceptanceCase.TaskName `
                    -CleanupCommand "Remove-DMPerformanceReportTask -Id '$acceptanceTaskId' -Confirm:`$false" | Out-Null
                Write-Host "$($acceptanceCase.CheckName): the array accepted the corrected $($acceptanceCase.ReportType.ToLowerInvariant()) body (task Id=$acceptanceTaskId)."
            }
        }
        finally {
            Invoke-PerformanceCleanup -Entries @($performanceCleanupRegistry | Select-Object -Skip $acceptanceRegistryStart)
        }
    }
}
