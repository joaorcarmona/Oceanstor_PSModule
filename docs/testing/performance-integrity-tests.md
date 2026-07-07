# Performance Integrity Tests

Performance/capacity checks are part of the same
`Tests/Integration/Invoke-GetterIntegrityValidation.ps1` runner, but they are
opt-in on top of it — separate from, and independent of, `-RunMutatingTests`.

## Key facts

- Performance tests are **opt-in**: nothing performance-related runs unless
  you pass at least one performance switch.
- **`-RunMutatingTests` alone does not run performance tests.** Mutating
  integrity and performance integrity are separate domains.
- `-IncludePerformance` is required for the realtime performance checks
  (Phases 1-2: monitoring status, per-object realtime samples, per-domain
  wrapper smoke checks).
- `Performance.Enabled = $true` must be set in
  `Tests/Integration/IntegrityValidationConfig.psd1` — this is the config-side
  acknowledgment gate. Without it, the dispatcher (`Invoke-PerformanceValidation`
  in `Tests/Integration/Private/PerformanceValidation.ps1`) emits a single
  `Performance validation | NotConfigured` check and returns immediately.
- `-IncludeExcelPerformance` requires `-IncludePerformance` to also be passed
  (Excel export layers on top of the realtime workflow).
- History/capacity report-task tests require their own explicit switches
  (`-IncludePerformanceHistory`, `-IncludeCapacityHistory`) **and**
  `Performance.AllowReportTaskCreation = $true` in config.
- Monitoring mutation (the sampling-interval round-trip) is double-gated:
  `-AllowMonitoringMutation` on the runner **and**
  `Performance.AllowMonitoringMutation = $true` in config.
- `POST performance_data` is a query-style, read-only batch read — it is
  allowlisted in `Assert-PerformanceTraceReadOnly` and confirmed live: the
  realtime and NAS/FileSystem trace audits pass with it in the request log.
- History/capacity report-task tests create temporary, test-owned report
  tasks named `<NamePrefix>_p<token>_<case>` (or a 31-character-capped
  variant — the array's `pms/report_task` API documents a 32-character limit
  but silently accepts, and silently drops, names one character over the
  actual 31-character cap).
- Report tasks are registered in a dedicated performance cleanup registry the
  moment their ID is captured, and are removed again by that captured ID at
  the end of the run — unless `-KeepCreatedReportTasks` is passed.
- A baseline snapshot of every pre-existing report task is taken before
  anything is created; cleanup refuses to delete any ID in that baseline,
  even if ownership tracking were ever wrong.
- Bond port performance tests (`Get-DMPortPerformance -PortType Bond`) report
  `NoData` on arrays with no Bond ports configured — this is expected, not a
  failure.

## Required credential setup

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
```

## Realtime performance

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformance
```

Required config:

```powershell
Performance = @{
    Enabled = $true
    AllowReportTaskCreation = $false
    AllowMonitoringMutation = $false
    HistoryLookbackHours = 2
    ReportTaskRetentionNumber = 1
}
```

Covers (all read-only `Get-*` calls, proven by a closing trace audit —
`Performance:TraceAudit:Realtime`):

- `Get-DMPerformanceMonitoring`
- `Get-DMPerformance` (System / Controller / explicit metric subset)
- `Get-DMSystemPerformance`, `Get-DMControllerPerformance`,
  `Get-DMStoragePoolPerformance`, `Get-DMDiskPerformance`,
  `Get-DMHostPerformance`, `Get-DMLunPerformance`
- `Get-DMPortPerformance` for FC / ETH / Bond port types

## Excel performance

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformance `
    -IncludeExcelPerformance
```

- Creates a local temporary workbook only — no array objects are created.
- Uses the module's performance cmdlets internally to populate the export.
- Local files are written under `-PerformanceOutputPath` (default: a
  run-scoped temp directory, `dm_integrity_perf_<runId>`) and are cleaned up
  by the performance cleanup backstop at the end of the run.
- `Export-DMStorageToExcel` itself is on the harness's excluded-commands
  list, so it never shows up as an unrepresented/`Blocked` command.

## Performance history

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformanceHistory
```

Required config:

```powershell
Performance = @{
    Enabled = $true
    AllowReportTaskCreation = $true
    AllowMonitoringMutation = $false
    HistoryLookbackHours = 2
    ReportTaskRetentionNumber = 1
}
```

- Creates temporary report tasks via `New-DMPerformanceReportTask` /
  `Invoke-DMPerformanceReportTask`, reads them back with
  `Get-DMPerformanceHistory` / `Get-DMPerformanceReportTask`, and removes
  them with `Remove-DMPerformanceReportTask`.
- Uses the same ownership registry as the mutation workflows, plus the
  performance-specific cleanup registry (`Register-PerformanceCleanup`).
- Deletes strictly by captured ID (`Remove-OwnedPerformanceReportTask`) —
  never by name, and never a task present in the pre-run baseline
  (`Assert-NotBaselinePerformanceReportTask`).
- Should not touch pre-existing report tasks; verify with
  `Get-DMPerformanceReportTask` before and after if you want to double-check.

## Capacity history

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludeCapacityHistory
```

Required config: same `Performance` block as performance history above
(`Enabled = $true`, `AllowReportTaskCreation = $true`).

Note: `-IncludePerformance` also runs the capacity workflow on its own (the
dispatcher runs `PerformanceCapacity.ps1` when either `-IncludePerformance`
or `-IncludeCapacityHistory` is passed) — pass `-IncludeCapacityHistory`
explicitly if you want capacity checks without the full realtime stage.

## Realtime + history + capacity combined

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformance `
    -IncludePerformanceHistory `
    -IncludeCapacityHistory
```

Report-task creation must be enabled in config
(`Performance.AllowReportTaskCreation = $true`) for the history/capacity
stages to actually run; without it they emit per-check `NotConfigured`
results instead of failing.

## Realtime + Excel + history + capacity combined

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformance `
    -IncludeExcelPerformance `
    -IncludePerformanceHistory `
    -IncludeCapacityHistory
```

This is a broader live run than any single stage above. Use it only after the
smaller stages have already passed individually.

## Monitoring mutation

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformance `
    -AllowMonitoringMutation
```

Required config:

```powershell
Performance = @{
    Enabled = $true
    AllowReportTaskCreation = $false
    AllowMonitoringMutation = $true
    HistoryLookbackHours = 2
    ReportTaskRetentionNumber = 1
}
```

- This is the only performance test area that changes a monitoring setting
  on the array (the realtime sampling interval).
- It captures the original `SamplingIntervalSeconds` first, changes it to a
  different settable value, verifies the change, and restores the captured
  original in a `finally` block.
- If the restore fails, the check fails loudly
  (`Set-DMPerformanceMonitoring:Restore` → `Failed`) and the exact manual
  restore command is printed as a warning.
- `Enable-DMPerformanceMonitoring` / `Disable-DMPerformanceMonitoring` are
  **never** exercised, even with this switch — toggling the master
  collection switch resets the collection begin time and is not a safe,
  restorable no-op. These always report `SkippedUnsafe`.
- Should not be enabled casually; only turn this on when you specifically
  need to validate the monitoring round-trip path.

## `-RunMutatingTests` does not include performance

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -RunMutatingTests
```

- This runs the standard mutating integrity workflows (LUN, LUN group,
  protection, QoS, host, NAS, mapping, initiators, quota, HyperCDP schedule).
- It does **not** automatically run any performance integrity tests.
- To run performance checks in the same invocation, add the relevant
  `-Include*` performance switches.
- If no performance switches are passed, performance cmdlets are not
  requested at all — `Invoke-PerformanceValidation` returns before doing
  anything (see `Tests/Integration/Private/PerformanceValidation.ps1:17-22`).

## Mutating + performance combined

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -RunMutatingTests `
    -IncludePerformance
```

Mutating object workflows and realtime performance validation are separate
domains, each independently gated, that can be enabled together in one run.

## Why performance commands may appear as `NotRequested` or previously `Blocked`

A live run against a Dorado array on 2026-07-06 showed all 19 performance
cmdlets as `Blocked`. Analysis confirmed this was **not**
a safety mechanism, REST-side rejection, or session failure:

- The run was invoked with `-RunMutatingTests` but **no** performance switch.
- Because no performance switch was passed, `Invoke-PerformanceValidation`
  returned immediately by design (the opt-in gate at
  `Tests/Integration/Private/PerformanceValidation.ps1:17-22`).
- The performance commands were never attempted — the run log contained zero
  performance REST calls.
- The `Blocked` status came from the coverage/reporting fallback in
  `Write-ValidationReport` (`Tests/Integration/Private/Reporting.ps1:126-140`):
  every public cmdlet not represented by any executed check is stamped
  `Blocked` on a mutating run, with the message "this command could not run
  because its test-owned prerequisite resource was not created successfully
  during this run" — a message that is only actually true for genuinely
  prerequisite-dependent commands (e.g. `Get-DMQuota` after `New-DMQuota`
  returns `NoData`), not for opt-in performance commands that simply were
  never requested.

A follow-up live run with `Performance.Enabled = $true` and
`-IncludePerformance` confirmed the performance machinery itself is healthy:
every realtime check passed, both trace audits passed (`POST
performance_data` correctly accepted as a query-style read-only POST), and no
report task was created.

**If a report shows performance cmdlets as `Blocked` but the run was executed
without `-IncludePerformance`, `-IncludePerformanceHistory`,
`-IncludeCapacityHistory`, or `-IncludeExcelPerformance`, the performance
cmdlets were not blocked by the array or REST API. They were not requested by
the test invocation.**

To get an accurate status for performance commands:

1. Check which `-Include*` performance switches were actually passed to the
   runner. None passed → performance is entirely `NotRequested`.
2. If a switch was passed but `Performance.Enabled = $false` in config, the
   single `Performance validation | NotConfigured` check is the accurate
   status.
3. If both the switch and `Performance.Enabled = $true` are set, look at the
   individual `PerformanceRead` checks (e.g. `Get-DMSystemPerformance`,
   `Performance:TraceAudit:Realtime`) for the real result.

A reporting-side fix to make this distinction visible per-cmdlet (rather than
relying on this explanation) is proposed but not yet implemented.
Until that lands, treat `Blocked` entries for performance/history/capacity
cmdlets as `NotRequested` whenever the corresponding switch was absent from
the invocation.
