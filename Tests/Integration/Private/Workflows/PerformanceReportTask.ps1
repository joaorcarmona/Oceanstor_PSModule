# Phase 4 (historical report-task pipeline) of the performance integrity validation.
#
# This is the one workflow family that creates objects on the array — report tasks and their
# export logs, nothing else. Safety invariants:
#   * a baseline snapshot of pre-existing report-task IDs is captured before anything is
#     created, and cleanup refuses to touch any baseline ID (Assert-NotBaselinePerformanceReportTask);
#   * task names carry the run prefix + per-run token, and creation refuses to claim a name
#     that already exists on the array;
#   * every created object's ID is captured from the create response and registered (ownership
#     registry + performance cleanup registry) before anything else runs;
#   * deletion happens only by captured ID, per-case in a finally block, with the runner-level
#     backstop behind it.

$script:PerformanceReportTaskWorkflow = {
    $reportTaskCheckNames = @(
        'New-DMPerformanceReportTask:Lifecycle', 'Get-DMPerformanceReportTask:ById',
        'Invoke-DMPerformanceReportTask', 'Save-DMPerformanceReportFile', 'Import-DMPerformanceReportCsv',
        'Verify:Remove-DMPerformanceReportTask',
        'Get-DMPerformanceHistory', 'Verify:Get-DMPerformanceHistory:TaskCleanup',
        'Get-DMPerformanceHistory:KeepReportTask', 'Verify:Get-DMPerformanceHistory:KeepReportTask'
    )

    if ($script:performanceReportTaskGateReason) {
        Add-SkippedResult -Name $reportTaskCheckNames -Status 'NotConfigured' -Reason $script:performanceReportTaskGateReason
        return
    }

    # pms v2 API probe + never-delete baseline (one call serves both purposes).
    $reportTaskBaselineTasks = $null
    try {
        $reportTaskBaselineTasks = @(Initialize-PerformanceReportTaskBaseline)
    }
    catch {
        Add-SkippedResult -Name $reportTaskCheckNames -Status 'Blocked' -Reason "The pms/report_task API probe failed (firmware may not expose the v2 pms interface): $($_.Exception.Message)"
        return
    }

    # Read-only target object: prefer the first controller, fall back to System.
    $historyTargetType = 'System'
    $historyTargetId = '0'
    $historyController = @(Get-DMController -WebSession $session | Select-Object -First 1)
    if ($historyController.Count -gt 0) {
        $historyTargetType = 'Controller'
        $historyTargetId = "$($historyController[0].Id)"
    }
    else {
        $historySystem = @(Get-DMSystem -WebSession $session)[0]
        if ($historySystem -and $historySystem.PSObject.Properties['Id'] -and "$($historySystem.Id)" -ne '') {
            $historyTargetId = "$($historySystem.Id)"
        }
    }
    Write-Host "Report-task checks target: $historyTargetType '$historyTargetId' (read-only entity)."

    $reportTaskRetention = if ($script:performanceConfig.ReportTaskRetentionNumber) { [int]$script:performanceConfig.ReportTaskRetentionNumber } else { 1 }
    $historyLookbackHours = if ($script:performanceConfig.HistoryLookbackHours) { [int]$script:performanceConfig.HistoryLookbackHours } else { 2 }

    # =========================================================================================
    # Case A — explicit report-task lifecycle: create -> query -> export -> download -> parse
    # =========================================================================================
    $rptName = New-ReportTaskName -Suffix "p$($script:perfRunToken)_rpt"
    $rptTaskId = $null
    $rptLogId = $null
    $rptZipPath = Join-Path $PerformanceOutputPath "$rptName.zip"
    $rptCaseRegistryStart = $performanceCleanupRegistry.Count

    try {
        $rptCreated = @(Invoke-MutationStep -Name 'New-DMPerformanceReportTask:Lifecycle' -ExpectedType 'OceanstorPerformanceReportTask' -Action {
            if (@($reportTaskBaselineTasks | Where-Object { $_.Name -eq $rptName }).Count -gt 0) {
                throw "A report task named '$rptName' already exists; refusing to claim it as test-owned."
            }
            New-DMPerformanceReportTask -WebSession $session -Name $rptName -TimeSegment OneDay -Format CSV `
                -RetentionNumber $reportTaskRetention -ObjectType $historyTargetType -ObjectId $historyTargetId -Confirm:$false
        })

        if ($rptCreated.Count -gt 0 -and "$($rptCreated[0].Id)" -ne '') {
            $rptTaskId = "$($rptCreated[0].Id)"
            Register-TestOwnedResource -Kind ReportTask -Identity $rptTaskId
            Register-PerformanceCleanup -Kind ReportTask -Id $rptTaskId -Name $rptName `
                -CleanupCommand "Remove-DMPerformanceReportTask -Id '$rptTaskId' -Confirm:`$false" | Out-Null
        }

        if ($rptTaskId) {
            Add-MutationReadVerification -Name 'Get-DMPerformanceReportTask:ById' -ExpectedType 'OceanstorPerformanceReportTask' -Action {
                $foundTasks = @(Get-DMPerformanceReportTask -WebSession $session -Id $rptTaskId | Where-Object { "$($_.Id)" -eq $rptTaskId })
                if ($foundTasks.Count -eq 0) {
                    throw "The created report task '$rptTaskId' ($rptName) was not returned by Get-DMPerformanceReportTask."
                }
                if (@($foundTasks[0].Contents).Count -eq 0) {
                    throw "The report task's Contents projection is empty; the corrected entities/indicators.basic projection did not resolve against live data."
                }
                Add-PerformanceArtifact -Name 'ReportTaskContentsProjection' -Value @($foundTasks[0].Contents | ForEach-Object {
                        [pscustomobject]@{
                            ReportType    = $_.ReportType
                            ComputeMode   = $_.ComputeMode
                            ObjectType    = $_.ObjectType
                            ObjectIdList  = @($_.ObjectIdList)
                            IndicatorList = @($_.IndicatorList)
                        }
                    })
                $foundTasks
            } | Out-Null

            $rptLog = @(Invoke-MutationStep -Name 'Invoke-DMPerformanceReportTask' -Action {
                Invoke-DMPerformanceReportTask -WebSession $session -Id $rptTaskId -TimeoutSec $PerformanceTimeoutSec -Confirm:$false
            })
            if ($rptLog.Count -gt 0 -and "$($rptLog[0].LogId)" -ne '') {
                $rptLogId = "$($rptLog[0].LogId)"
                Register-TestOwnedResource -Kind ReportLog -Identity $rptLogId
                Register-PerformanceCleanup -Kind ReportLog -Id $rptLogId -Name "$rptName export log" `
                    -CleanupCommand "Invoke-DeviceManager -Method DELETE -Resource 'pms/report_task/task_log?log_id=$rptLogId' -ApiV2" | Out-Null
            }
        }
        else {
            Add-SkippedResult -Name @('Get-DMPerformanceReportTask:ById', 'Invoke-DMPerformanceReportTask') -Status 'Blocked' `
                -Reason 'The report task was not created, so the rest of the lifecycle cannot be validated.'
        }

        if ($rptLogId) {
            Register-PerformanceCleanup -Kind LocalFile -Id $rptZipPath -Name 'report export zip' `
                -CleanupCommand "Remove-Item -LiteralPath '$rptZipPath' -Force" | Out-Null

            Add-ValidationResult -Name 'Save-DMPerformanceReportFile' -Category 'Mutation' -Action {
                Save-DMPerformanceReportFile -WebSession $session -LogId $rptLogId -TaskId $rptTaskId -Path $rptZipPath -Force | Out-Null
                if (-not (Test-Path -LiteralPath $rptZipPath)) {
                    throw 'The report download did not create the zip file.'
                }
                $rptZipFile = Get-Item -LiteralPath $rptZipPath
                if ($rptZipFile.Length -eq 0) {
                    throw 'The downloaded report file is empty.'
                }
                $zipMagic = [System.IO.File]::ReadAllBytes($rptZipPath)[0..1]
                if ($zipMagic[0] -ne 0x50 -or $zipMagic[1] -ne 0x4B) {
                    throw 'The downloaded report file does not start with a zip signature (PK).'
                }
                [pscustomobject]@{ Path = $rptZipPath; Bytes = $rptZipFile.Length }
            } | Out-Null

            Add-ValidationResult -Name 'Import-DMPerformanceReportCsv' -Category 'Mutation' -Action {
                $rptRows = @(Import-DMPerformanceReportCsv -ZipPath $rptZipPath)
                if ($rptRows.Count -gt 0) {
                    $rptHeaders = @($rptRows[0].PSObject.Properties.Name)
                    Add-PerformanceArtifact -Name 'PerformanceCsvHeaders' -Value $rptHeaders
                    Write-Host "Performance report CSV headers (live confirmation): $($rptHeaders -join ' | ')"
                }
                else {
                    Add-PerformanceArtifact -Name 'PerformanceCsvHeaders' -Value @()
                }
                $rptRows
            } | Out-Null
        }
        elseif ($rptTaskId) {
            Add-SkippedResult -Name @('Save-DMPerformanceReportFile', 'Import-DMPerformanceReportCsv') -Status 'Blocked' `
                -Reason 'No export log was produced (export may have timed out), so the download/parse steps cannot be validated.'
        }
    }
    finally {
        Invoke-PerformanceCleanup -Entries @($performanceCleanupRegistry | Select-Object -Skip $rptCaseRegistryStart)
    }

    if ($rptTaskId -and -not $KeepCreatedReportTasks) {
        Add-ValidationResult -Name 'Verify:Remove-DMPerformanceReportTask' -Category 'MutationRead' -Action {
            $remainingTasks = @(Get-DMPerformanceReportTask -WebSession $session | Where-Object { "$($_.Id)" -eq $rptTaskId })
            if ($remainingTasks.Count -gt 0) {
                throw "Report task '$rptTaskId' still exists after cleanup."
            }
            [pscustomobject]@{ Removed = $true }
        } | Out-Null
    }

    # =========================================================================================
    # Case B — Get-DMPerformanceHistory orchestrator (creates AND cleans its own task)
    # =========================================================================================
    $historyStartTime = (Get-Date).AddHours(-1 * $historyLookbackHours)
    $historyEndTime = Get-Date
    $historyPreTaskIds = @(Get-PerformanceReportTaskSnapshot | ForEach-Object { "$($_.Id)" })

    Add-ValidationResult -Name 'Get-DMPerformanceHistory' -Category 'Mutation' -Action {
        $historyRows = @(Get-DMPerformanceHistory -WebSession $session -ObjectType $historyTargetType -ObjectId $historyTargetId `
                -Metric TotalIOPS, AvgLatencyMs -StartTime $historyStartTime -EndTime $historyEndTime -TimeoutSec $PerformanceTimeoutSec)
        foreach ($historyRow in $historyRows) {
            Assert-PerformanceSample -Sample $historyRow -ExpectedObjectType $historyTargetType -AllowMinValueTimestamp
        }
        # Zero rows surface as NoData via the harness ("archive history may be unavailable for
        # the requested window"), not as a failure.
        $historyRows
    } | Out-Null

    Add-ValidationResult -Name 'Verify:Get-DMPerformanceHistory:TaskCleanup' -Category 'MutationRead' -Action {
        $historyPostTasks = @(Get-PerformanceReportTaskSnapshot)
        $historyLeftovers = @($historyPostTasks | Where-Object { "$($_.Id)" -notin $historyPreTaskIds })
        if ($historyLeftovers.Count -gt 0) {
            throw "Get-DMPerformanceHistory left $($historyLeftovers.Count) report task(s) behind: $(@($historyLeftovers | ForEach-Object { "$($_.Name) ($($_.Id))" }) -join ', ')."
        }
        [pscustomobject]@{ CleanedUp = $true }
    } | Out-Null

    # =========================================================================================
    # Case C — -KeepReportTask leaves the task in place; then delete it by captured ID
    # =========================================================================================
    $keepPreTaskIds = @(Get-PerformanceReportTaskSnapshot | ForEach-Object { "$($_.Id)" })
    $keptTaskId = $null
    $keptTaskName = $null
    $keepCaseRegistryStart = $performanceCleanupRegistry.Count

    try {
        Add-ValidationResult -Name 'Get-DMPerformanceHistory:KeepReportTask' -Category 'Mutation' -Action {
            Get-DMPerformanceHistory -WebSession $session -ObjectType $historyTargetType -ObjectId $historyTargetId `
                -Metric TotalIOPS -StartTime $historyStartTime -EndTime $historyEndTime -TimeoutSec $PerformanceTimeoutSec -KeepReportTask | Out-Null
            [pscustomobject]@{ Completed = $true }
        } | Out-Null

        $keepNewTasks = @(Get-PerformanceReportTaskSnapshot | Where-Object { "$($_.Id)" -notin $keepPreTaskIds })
        $keptCandidates = @($keepNewTasks | Where-Object { "$($_.Name)" -like 'DMPerfHistory_*' })

        Add-ValidationResult -Name 'Verify:Get-DMPerformanceHistory:KeepReportTask' -Category 'MutationRead' -Action {
            if ($keptCandidates.Count -eq 0) {
                throw '-KeepReportTask did not leave the internally created DMPerfHistory_* report task in place.'
            }
            if ($keptCandidates.Count -gt 1) {
                throw "Expected exactly one new DMPerfHistory_* report task, found $($keptCandidates.Count): $(@($keptCandidates | ForEach-Object Name) -join ', ')."
            }
            $keptCandidates
        } | Out-Null

        if ($keptCandidates.Count -eq 1) {
            # Created by this run's own Get-DMPerformanceHistory call (absent from the pre-call
            # snapshot, cmdlet-specific name pattern) -> legitimately test-owned.
            $keptTaskId = "$($keptCandidates[0].Id)"
            $keptTaskName = "$($keptCandidates[0].Name)"
            Register-TestOwnedResource -Kind ReportTask -Identity $keptTaskId
            # -KeepReportTask also keeps the export log; RemoveLogsFirst sweeps the owned
            # task's logs (queried strictly by the captured task ID) before the task delete.
            Register-PerformanceCleanup -Kind ReportTask -Id $keptTaskId -Name $keptTaskName -RemoveLogsFirst `
                -CleanupCommand "Remove-DMPerformanceReportTask -Id '$keptTaskId' -Confirm:`$false" | Out-Null
        }
    }
    finally {
        Invoke-PerformanceCleanup -Entries @($performanceCleanupRegistry | Select-Object -Skip $keepCaseRegistryStart)
    }
}
