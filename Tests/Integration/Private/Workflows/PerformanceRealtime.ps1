# Phase 1 (realtime engine + monitoring read checks) and Phase 2 (per-domain wrapper smoke
# checks) of the performance integrity validation. Read-only by construction: only Get-*
# cmdlets run, and a trace audit proves no mutating REST call was issued. The optional
# monitoring round-trip at the end is double-gated (-AllowMonitoringMutation switch AND
# Performance.AllowMonitoringMutation in config) and restores the captured original state.

$script:PerformanceRealtimeWorkflow = {
    $realtimeTraceStart = $performanceRequests.Count

    # --- Phase 1.1: monitoring status (read-only) --------------------------------------------
    $monitoringStatus = @(Add-ValidationResult -Name 'Get-DMPerformanceMonitoring' -Category 'PerformanceRead' -Action {
        Get-DMPerformanceMonitoring -WebSession $session
    })
    if ($monitoringStatus.Count -gt 0) {
        Add-PerformanceArtifact -Name 'MonitoringStatus' -Value ([pscustomobject]@{
            Enabled                 = $monitoringStatus[0].Enabled
            SamplingIntervalSeconds = $monitoringStatus[0].SamplingIntervalSeconds
            ArchiveEnabled          = $monitoringStatus[0].ArchiveEnabled
            ArchiveIntervalSeconds  = $monitoringStatus[0].ArchiveIntervalSeconds
        })
        if (-not $monitoringStatus[0].Enabled) {
            Write-Host 'NOTE: performance monitoring is disabled on the array; realtime metric values may all be null (shape assertions still apply).'
        }
    }

    # --- Phase 1.2: system realtime sample ---------------------------------------------------
    $perfSystemObject = @(Get-DMSystem -WebSession $session)[0]
    $perfSystemId = if ($perfSystemObject -and $perfSystemObject.PSObject.Properties['Id'] -and "$($perfSystemObject.Id)" -ne '') {
        "$($perfSystemObject.Id)"
    }
    else {
        '0'
    }

    Add-ValidationResult -Name 'Get-DMPerformance:System' -Category 'PerformanceRead' -Action {
        $perfSamples = @(Get-DMPerformance -WebSession $session -ObjectType System -ObjectId $perfSystemId)
        if ($perfSamples.Count -eq 0) {
            throw "Get-DMPerformance returned no sample for System ObjectId '$perfSystemId'."
        }
        foreach ($perfSample in $perfSamples) {
            Assert-PerformanceSample -Sample $perfSample -ExpectedObjectType System
        }
        $perfSamples
    } | Out-Null

    # --- Phase 1.3: controller realtime sample (ID membership) -------------------------------
    $perfControllers = @(Get-DMController -WebSession $session | Select-Object -First 1)
    if ($perfControllers.Count -eq 0) {
        Add-SkippedResult -Name 'Get-DMPerformance:Controller' -Status 'NoData' -Category 'PerformanceRead' -Reason 'Get-DMController returned no controllers.'
    }
    else {
        $perfControllerId = "$($perfControllers[0].Id)"
        Add-ValidationResult -Name 'Get-DMPerformance:Controller' -Category 'PerformanceRead' -Action {
            $perfSamples = @(Get-DMPerformance -WebSession $session -ObjectType Controller -ObjectId $perfControllerId)
            if ($perfSamples.Count -eq 0) {
                throw "Get-DMPerformance returned no sample for Controller ObjectId '$perfControllerId'."
            }
            foreach ($perfSample in $perfSamples) {
                Assert-PerformanceSample -Sample $perfSample -ExpectedObjectType Controller -AllowedObjectIds @($perfControllerId)
            }
            $perfSamples
        } | Out-Null
    }

    # --- Phase 1.4: explicit metric subset resolves to exactly those properties --------------
    Add-ValidationResult -Name 'Get-DMPerformance:MetricSubset' -Category 'PerformanceRead' -Action {
        $perfSamples = @(Get-DMPerformance -WebSession $session -ObjectType System -ObjectId $perfSystemId -Metric TotalIOPS, AvgLatencyMs)
        if ($perfSamples.Count -eq 0) {
            throw 'Get-DMPerformance returned no sample for the explicit metric subset.'
        }
        foreach ($perfSample in $perfSamples) {
            Assert-PerformanceSample -Sample $perfSample -ExpectedObjectType System -ExactMetricNames @('TotalIOPS', 'AvgLatencyMs')
        }
        $perfSamples
    } | Out-Null

    # --- Phase 2: per-domain wrapper smoke checks --------------------------------------------
    Add-ValidationResult -Name 'Get-DMSystemPerformance' -Category 'PerformanceRead' -Action {
        $perfSamples = @(Get-DMSystemPerformance -WebSession $session)
        if ($perfSamples.Count -eq 0) {
            throw 'Get-DMSystemPerformance returned no samples.'
        }
        foreach ($perfSample in $perfSamples) {
            Assert-PerformanceSample -Sample $perfSample -ExpectedObjectType System
        }
        $perfSamples
    } | Out-Null

    $perfWrapperCases = @(
        @{ Name = 'Get-DMControllerPerformance'; ObjectType = 'Controller'; Getter = { Get-DMController -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMControllerPerformance -WebSession $session } }
        @{ Name = 'Get-DMStoragePoolPerformance'; ObjectType = 'StoragePool'; Getter = { Get-DMstoragePool -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMStoragePoolPerformance -WebSession $session } }
        @{ Name = 'Get-DMDiskPerformance'; ObjectType = 'Disk'; Getter = { Get-DMdisk -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMDiskPerformance -WebSession $session } }
        @{ Name = 'Get-DMHostPerformance'; ObjectType = 'Host'; Getter = { Get-DMhost -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMHostPerformance -WebSession $session } }
        @{ Name = 'Get-DMLunPerformance'; ObjectType = 'LUN'; Getter = { Get-DMlun -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMLunPerformance -WebSession $session } }
        @{ Name = 'Get-DMPortPerformance:FC'; ObjectType = 'FCPort'; Getter = { Get-DMPortFc -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMPortPerformance -WebSession $session -PortType FC } }
        @{ Name = 'Get-DMPortPerformance:ETH'; ObjectType = 'EthernetPort'; Getter = { Get-DMPortETH -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMPortPerformance -WebSession $session -PortType ETH } }
        @{ Name = 'Get-DMPortPerformance:Bond'; ObjectType = 'BondPort'; Getter = { Get-DMPortBond -WebSession $session }; Wrapper = { param($objects) $objects | Get-DMPortPerformance -WebSession $session -PortType Bond } }
    )

    foreach ($perfCase in $perfWrapperCases) {
        $perfInputs = @(& $perfCase.Getter | Select-Object -First $MaxObjectsPerType)
        if ($perfInputs.Count -eq 0) {
            Add-SkippedResult -Name $perfCase.Name -Status 'NoData' -Category 'PerformanceRead' -Reason "No $($perfCase.ObjectType) objects exist on the array."
            continue
        }
        $perfInputIds = @($perfInputs | ForEach-Object { "$($_.Id)" })

        Add-ValidationResult -Name $perfCase.Name -Category 'PerformanceRead' -Action {
            $perfSamples = @(& $perfCase.Wrapper $perfInputs)
            if ($perfSamples.Count -eq 0) {
                throw "$($perfCase.Name) returned no samples for $($perfInputIds.Count) input object(s) ($($perfInputIds -join ', '))."
            }
            foreach ($perfSample in $perfSamples) {
                Assert-PerformanceSample -Sample $perfSample -ExpectedObjectType $perfCase.ObjectType -AllowedObjectIds $perfInputIds
            }
            foreach ($perfInputId in $perfInputIds) {
                if (@($perfSamples | Where-Object { "$($_.ObjectId)" -eq $perfInputId }).Count -eq 0) {
                    throw "$($perfCase.Name) returned no sample for requested ObjectId '$perfInputId'."
                }
            }
            # Live observation (Dorado 10.10.10.24): controllers sample independently, so one
            # batched call can return per-object timestamps that straddle a sampling tick.
            # Allow a spread of up to one maximum sampling interval (60 s) instead of exact
            # equality; a larger spread would indicate separate unbatched calls.
            $perfTimestamps = @($perfSamples | ForEach-Object { $_.Timestamp } | Sort-Object -Unique)
            if ($perfTimestamps.Count -gt 1) {
                $perfTimestampSpreadSeconds = ($perfTimestamps[-1] - $perfTimestamps[0]).TotalSeconds
                if ($perfTimestampSpreadSeconds -gt 60) {
                    throw "$($perfCase.Name) samples carry $($perfTimestamps.Count) distinct timestamps spanning $perfTimestampSpreadSeconds seconds; expected at most one sampling interval (60 s) for a single batched call."
                }
            }
            $perfSamples
        } | Out-Null
    }

    # --- Phase 1.5 / 2 closing audit: prove no mutating REST call ran ------------------------
    Add-ValidationResult -Name 'Performance:TraceAudit:Realtime' -Category 'PerformanceRead' -Action {
        Assert-PerformanceTraceReadOnly -FromIndex $realtimeTraceStart
    } | Out-Null

    # --- Optional monitoring round-trip (Step 7): NEVER part of a default run ----------------
    $monitoringCheckNames = @('Set-DMPerformanceMonitoring:MinimalChange', 'Set-DMPerformanceMonitoring:ChangeReadBack', 'Set-DMPerformanceMonitoring:Restore')
    if (-not $AllowMonitoringMutation) {
        Add-SkippedResult -Name $monitoringCheckNames -Status 'NotRequested' -Category 'Mutation' `
            -Reason 'Call the runner with -AllowMonitoringMutation (and set Performance.AllowMonitoringMutation = $true) to run the monitoring round-trip.'
    }
    elseif (-not $script:performanceConfig.AllowMonitoringMutation) {
        Add-SkippedResult -Name $monitoringCheckNames -Status 'NotConfigured' -Category 'Mutation' `
            -Reason 'Set Performance.AllowMonitoringMutation = $true in IntegrityValidationConfig.psd1 to acknowledge the monitoring round-trip.'
    }
    else {
        # Enable-/Disable-DMPerformanceMonitoring are deliberately NOT exercised: toggling the
        # master collection switch resets the collection begin time and interrupts sampling, so
        # a disable->enable round-trip is not a safe no-op on a production-like array.
        Add-SkippedResult -Name @('Enable-DMPerformanceMonitoring', 'Disable-DMPerformanceMonitoring') -Status 'SkippedUnsafe' -Category 'Mutation' `
            -Reason 'Master-switch toggling interrupts collection and is not a restorable no-op; only the sampling-interval round-trip is exercised.'

        $originalMonitoring = @(Get-DMPerformanceMonitoring -WebSession $session)[0]
        $settableIntervals = @(5, 10, 30, 60)
        if (-not $originalMonitoring -or -not $originalMonitoring.SamplingIntervalSeconds) {
            Add-SkippedResult -Name $monitoringCheckNames -Status 'Blocked' -Category 'Mutation' `
                -Reason 'Could not capture the original monitoring strategy; refusing to mutate without a restore point.'
        }
        elseif ([int]$originalMonitoring.SamplingIntervalSeconds -notin $settableIntervals) {
            Add-SkippedResult -Name $monitoringCheckNames -Status 'Blocked' -Category 'Mutation' `
                -Reason "Current sampling interval $($originalMonitoring.SamplingIntervalSeconds)s is not one of the settable values ($($settableIntervals -join ', ')); restoring it exactly would be impossible."
        }
        else {
            $originalInterval = [int]$originalMonitoring.SamplingIntervalSeconds
            $temporaryInterval = @($settableIntervals | Where-Object { $_ -ne $originalInterval })[0]
            Write-Host "Monitoring round-trip: sampling interval $originalInterval s -> $temporaryInterval s -> restore $originalInterval s."

            $monitoringRestored = $false
            $changeApplied = $false
            try {
                Invoke-MutationStep -Name 'Set-DMPerformanceMonitoring:MinimalChange' -Action {
                    Set-DMPerformanceMonitoring -WebSession $session -SamplingIntervalSeconds $temporaryInterval -Confirm:$false
                } | Out-Null

                # The array refuses to modify the sampling-interval policy while performance
                # statistics collection is switched on (API 1077949051): the change above is
                # rejected, MinimalChange records NoData, and the interval is left untouched.
                # Confirm the change actually landed before asserting the read-back or attempting
                # a restore, so a pre-existing statistics switch is reported as a skipped
                # precondition rather than a spurious "expected X, got Y" change failure.
                $afterChange = @(Get-DMPerformanceMonitoring -WebSession $session)
                $changeApplied = $afterChange.Count -gt 0 -and [int]$afterChange[0].SamplingIntervalSeconds -eq $temporaryInterval

                if ($changeApplied) {
                    Add-MutationReadVerification -Name 'Set-DMPerformanceMonitoring:ChangeReadBack' -Action {
                        $currentMonitoring = @(Get-DMPerformanceMonitoring -WebSession $session)
                        if ($currentMonitoring.Count -gt 0 -and [int]$currentMonitoring[0].SamplingIntervalSeconds -ne $temporaryInterval) {
                            throw "Expected sampling interval $temporaryInterval after the change, got $($currentMonitoring[0].SamplingIntervalSeconds)."
                        }
                        $currentMonitoring
                    } | Out-Null
                }
                else {
                    Add-SkippedResult -Name @('Set-DMPerformanceMonitoring:ChangeReadBack', 'Set-DMPerformanceMonitoring:Restore') -Status 'Blocked' -Category 'Mutation' `
                        -Reason 'The array did not apply the sampling-interval change (typically API 1077949051 when performance statistics collection is switched on); the read-back and restore were skipped because the monitoring strategy was left unchanged.'
                }
            }
            finally {
                if ($changeApplied) {
                try {
                    Set-DMPerformanceMonitoring -WebSession $session -SamplingIntervalSeconds $originalInterval -Confirm:$false | Out-Null
                    $currentMonitoring = @(Get-DMPerformanceMonitoring -WebSession $session)
                    if ($currentMonitoring.Count -gt 0 -and [int]$currentMonitoring[0].SamplingIntervalSeconds -eq $originalInterval) {
                        $monitoringRestored = $true
                    }
                }
                catch {
                    Write-Warning "Monitoring restore attempt threw: $($_.Exception.Message)"
                }

                if ($monitoringRestored) {
                    $checks.Add([pscustomobject]@{
                        Name = 'Set-DMPerformanceMonitoring:Restore'; Category = 'Mutation'; Status = 'Passed'
                        DurationMs = $null; Count = 1; ExpectedType = $null; ActualTypes = @('PSCustomObject'); Error = $null
                    })
                }
                else {
                    $checks.Add([pscustomobject]@{
                        Name = 'Set-DMPerformanceMonitoring:Restore'; Category = 'Mutation'; Status = 'Failed'
                        DurationMs = $null; Count = 0; ExpectedType = $null; ActualTypes = @()
                        Error = "Failed to restore the original sampling interval ($originalInterval s)."
                    })
                    Write-Warning '*** MONITORING RESTORE FAILED ***'
                    Write-Warning "Restore the original state manually with: Set-DMPerformanceMonitoring -SamplingIntervalSeconds $originalInterval -Confirm:`$false"
                }
                }
            }
        }
    }
}
