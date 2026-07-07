# Testing POSH-Oceanstor

This directory contains two complementary test layers:

- `Unit`: isolated Pester tests that mock REST calls and validate module behavior locally.
- `Integration`: live validation against an OceanStor array, including optional test-owned mutation workflows.

The recommended order is:

1. Run the unit suite.
2. Run read-only integration validation.
3. Review `Integration/IntegrityValidationConfig.psd1`.
4. Run mutation integration validation only against an appropriate test array.

The detailed test inventory and dependency order are documented in
`TestExecutionOrder.xml`.

For a fuller walkthrough of every test domain, switch, and config gate, see
[`docs/testing/`](../docs/testing/README.md):

- [Unit tests](../docs/testing/unit-tests.md)
- [Integrity tests](../docs/testing/integrity-tests.md)
- [Performance integrity tests](../docs/testing/performance-integrity-tests.md)
- [Test schema & organization](../docs/testing/test-schema-organization.md)
- [Live validation safety](../docs/testing/live-validation-safety.md)

Public storage-domain documentation is under:

- [Block storage](../docs/block-storage/README.md)
- [File storage](../docs/file-storage/README.md)
- [QoS](../docs/qos/README.md)
- [Snapshots](../docs/snapshots/README.md)

## Prerequisites

- PowerShell 7 is recommended.
- Pester 5.0.0 or later is required for unit tests.
- Live integration tests require network access to an OceanStor array.
- Live credentials are requested interactively and are not stored in the
  configuration file.

Run commands from the repository root unless stated otherwise.

## Unit Tests

Unit tests are grouped by function or feature under `Unit/Private` and
`Unit/Public`. Each suite is designed to be independent: it should not require a
previous suite to run first.

Run the full unit suite:

```powershell
./Tests/Invoke-UnitTests.ps1
```

Use quieter output:

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal
```

Write a JUnit XML report, suitable for CI:

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal -ResultPath ./Reports/Pester.xml
```

The GitHub Actions workflow uses the JUnit form above, writing into `Reports/`.

## Integration Methodology

The live integration runner is:

```text
Tests/Integration/Invoke-GetterIntegrityValidation.ps1
```

Every live run:

1. Prompts for credentials and creates an OceanStor WebSession.
2. Runs read-only getter validation.
3. Confirms returned object types when a type is expected.
4. Writes a JSON report.

When mutation mode is explicitly enabled, the runner also:

1. Creates resources with a generated test prefix and run timestamp.
2. Registers every created resource as test-owned.
3. Updates descriptions and renames supported resources immediately after creation.
4. Uses the renamed identities for dependent resources and associations.
5. Reads resources back to verify renames, creation, and associations.
6. Removes resources in reverse dependency order using their current names.
7. Writes a detailed mutation request trace.

Cleanup actions are registered as resources are created. Removal commands refuse
to modify resources that were not created and registered by the same run.

## Read-Only Integration

Use read-only mode first. It exercises getter functions without intentionally
creating, modifying, or deleting array resources.

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN'
```

Show one persistent output line for each completed check:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -ShowTestExecution
```

Hide interactive progress when redirecting console output:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -NoProgress
```

For lab arrays with self-signed certificates, opt out of TLS certificate
validation explicitly:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -SkipCertificateCheck
```

## Mutation Integration

Mutation mode is opt-in twice:

1. `AllowMutatingTests` must be `$true` in
   `Integration/IntegrityValidationConfig.psd1`.
2. The runner must be called with `-RunMutatingTests`.

Before running, review:

- `StoragePoolId`: existing pool used only as a placement target.
- `NamePrefix`: prefix for generated test-owned resource names.
- Enabled workflow sections: `Lun`, `LunGroup`, `Protection`, `QoS`, `Host`,
  `Nas`, `Mapping`, `Initiators`, and the disabled-by-default
  `HyperCDPSchedule`, `Replication`, and `HyperMetro` sections.
- Initiator identities: supply only unused identities that may be created and
  deleted during the run.

Run the full configured create, verify, and cleanup workflow:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -RunMutatingTests `
    -SkipCertificateCheck `
    -ShowTestExecution
```

Run the extra multi-LUN pipeline regression coverage for `New-DMLun`,
`Set-DMLun`, `Add-DMLunToLunGroup`, `Remove-DMLunFromLunGroup`, and
`Remove-DMLun`:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -RunMutatingTests `
    -RunPipelineBatchCoverage `
    -SkipCertificateCheck `
    -ShowTestExecution
```

This creates three additional test-owned LUNs and can add noticeable runtime on
arrays where LUN creation or removal is slow. The same coverage can be enabled
in a custom configuration file with `LunGroup.EnablePipelineBatchCoverage =
$true`.

Enable the non-secure HyperCDP schedule workflow in the configuration file:

```powershell
HyperCDPSchedule = @{
    Enabled = $true
    FrequencyValueSeconds = 3600
    FrequencySnapshotCount = 2
}
```

This workflow creates a disabled block HyperCDP schedule, associates the
test-owned LUN, removes that association, toggles the schedule, and deletes it.
It does not use protection groups or secure snapshots.

## Replication and HyperMetro Workflows

The `Replication` and `HyperMetro` sections are disabled by default because
they create remote replication and HyperMetro objects and can change DR state.
Enable them only against a lab array pair, with a remote device and remote LUN
reserved for validation, and (for HyperMetro) an existing SAN domain:

```powershell
Replication = @{
    Enabled = $true
    AllowDrMutation = $true
    AllowFailover = $false        # gates Switch-DMReplicationPair / group switchover
    RemoteDeviceName = 'lab-remote-array'
    RemoteLunName = 'dm_integrity_rlun'
    RemoteServiceType = 'ReplicationSecondaryLun'
}

HyperMetro = @{
    Enabled = $true
    AllowDrMutation = $true
    AllowPrioritySwitch = $false  # gates priority-switch commands
    RemoteDeviceName = 'lab-remote-array'
    RemoteLunName = 'dm_integrity_mlun'
    RemoteServiceType = 'HyperMetroSecondaryLun'
    DomainName = 'lab-metro-domain'
}
```

Failover-like operations are opt-in separately: switchover commands run only
when `Replication.AllowFailover` is `$true`, and HyperMetro priority switches
run only when `HyperMetro.AllowPrioritySwitch` is `$true`. Otherwise they are
reported as `SkippedUnsafe` — intentionally not counted as passed, because
they change which site serves production-like data. The workflows only mutate
pairs and groups created by the same run; they never create, modify, or delete
HyperMetro domains or quorum associations, and never touch pre-existing DR
objects. Do not enable these sections casually: even test-owned DR operations
consume replication links and array resources shared with real DR traffic.
See `docs/replication-hypermetro/safety-and-live-validation.md` for the full
safety model.

Use a separate configuration file when testing a different array or subset of
workflows:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -ConfigurationPath './Tests/Integration/MyLabConfig.psd1' `
    -RunMutatingTests
```

## Performance Integrity Validation

The performance/capacity checks (Phases 1-5 of the performance implementation)
are part of the same runner and are opt-in twice, mirroring mutation mode:

1. The `Performance` section in `Integration/IntegrityValidationConfig.psd1`
   must have `Enabled = $true` (plus `AllowReportTaskCreation = $true` for the
   history/capacity phases).
2. The runner must be called with one or more of the performance switches.

Normal unit tests (`Invoke-Pester Tests/Unit`) and existing validation runs are
unaffected: with no performance switch the runner behaves exactly as before.

Read-only realtime checks (Phases 1-2 plus NAS/FileSystem realtime — only
`Get-*` calls; a trace audit asserts no mutating REST call ran):

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -SkipCertificateCheck `
    -IncludePerformance
```

Excel performance-export checks (Phase 3 — array reads only; writes and then
deletes local `.xlsx` files under `-PerformanceOutputPath`; requires the
ImportExcel module):

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -SkipCertificateCheck `
    -IncludePerformance -IncludeExcelPerformance
```

Report-task/history and capacity checks (Phases 4-5). These create **report
tasks only** — metadata, never storage objects. Every created task is named
`<NamePrefix>_<runId>_p<token>_<case>`, its ID is captured from the create
response, registered as test-owned, and deleted by that captured ID during the
same run. Pre-existing report tasks are snapshotted first and are never
touched; a baseline guard refuses to delete any pre-existing ID:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -SkipCertificateCheck `
    -IncludePerformance -IncludePerformanceHistory -IncludeCapacityHistory
```

Additional performance switches:

- `-KeepCreatedReportTasks`: leave test-created report tasks/logs in place for
  debugging; their IDs and manual cleanup commands are printed and recorded.
- `-MaxObjectsPerType <n>` (default 2): how many existing objects each wrapper
  smoke check reads.
- `-PerformanceTimeoutSec <n>` (default 300): report export poll timeout.
- `-PerformanceOutputPath <dir>`: where downloaded zips/xlsx files go
  (defaults to a run-scoped temp directory).
- `-AllowMonitoringMutation`: opt-in monitoring round-trip (also requires
  `Performance.AllowMonitoringMutation = $true` in the config). It captures the
  original sampling interval, changes it once, verifies, and restores the
  original in a `finally` block; a failed restore fails loudly and prints the
  exact manual restore command. Default runs never modify monitoring settings.

## Live-Confirmed Findings (2026-07-06, Dorado V600R005C27, 10.10.10.24)

The performance/capacity integrity checks above were run live end to end
(`-IncludePerformance -IncludeExcelPerformance -IncludePerformanceHistory
-IncludeCapacityHistory`). These findings are confirmed against that array and
are reflected in the current cmdlet implementations, not aspirational:

- **Performance and capacity CSV exports are long-format**: one row per
  object/metric/timestamp, with headers `Object Type, Object Instance,
  Statistical Metric, Value, Time, Object Type ID, Object Instance ID,
  Statistical Metric ID`.
- **Confirmed capacity metric names**: `Total capacity(MB)`,
  `Used capacity(MB)`, `Capacity usage(%)` (System and StoragePool), plus
  `Mapped LUN capacity(MB)` (StoragePool only).
- **`task_log` carries no status field.** A report is ready when a new
  `log_id` entry appears for the task after `pms/report_task/export` is
  triggered — `Invoke-DMPerformanceReportTask`'s poll-for-new-entry design is
  confirmed correct on this firmware.
- **Downloading a report requires both `task_id` and `log_id`**
  (`Save-DMPerformanceReportFile -LogId ... -TaskId ...`); omitting `task_id`
  returns a small JSON error body instead of a truncated zip.
- **Report-task names are capped at 31 characters** on this array (the REST
  reference documents 32); longer names are silently accepted but no task is
  created.
- **NAS/FileSystem realtime metrics** (`Get-DMFileSystemPerformance`):
  `Ops`, `ReadOps`, `WriteOps`, `ReadBandwidthMBps`, `WriteBandwidthMBps`,
  `AvgReadOpsResponseTimeUs`, `AvgWriteOpsResponseTimeUs` all returned without
  error for the `FileSystem` object type. Every value was `0.0` on this run
  because the lab array had no NAS I/O in flight during validation — indicator
  applicability is confirmed, plausible nonzero values under load are not.
- **Monitoring status observed live**: 5 s sampling interval, archive enabled,
  60 s archive interval.
- **Live cleanup result**: after the full staged run, `Get-DMPerformanceReportTask`
  returned zero residual `dm_integrity_*`/history/capacity tasks, and all
  locally-downloaded zips/xlsx files and their run-scoped temp directories were
  removed.
- **Remaining known limitations**: `-AllowMonitoringMutation` was not
  exercised this run (opt-in, not requested); `task_log` field names on other
  firmware versions are unverified beyond this array.

Full detail and rationale for every fix are logged in
`.archived-commands/PerformanceGAP.md`; the raw live artifact (CSV headers,
monitoring status, NAS metric values, cleanup registry) is at
`Reports/performance-integrity-artifacts.json`.

Safe invocation example used for this validation:

```powershell
$storageIP = "10.10.10.24"
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformance -IncludeExcelPerformance `
    -IncludePerformanceHistory -IncludeCapacityHistory `
    -ConfigurationPath './Tests/Integration/IntegrityValidationConfig.psd1'
```

`Performance.Enabled` and `Performance.AllowReportTaskCreation` must be `$true`
in whatever configuration file is passed — use a local/untracked copy rather
than editing the committed defaults if this is not a dedicated test array.

## Network Cmdlet Coverage

Network getters (`Get-DMPortETH`, `Get-DMPortFc`, `Get-DMPortSAS`,
`Get-DMInterfaceModule`, `Get-DMPortBond`, `Get-DMvLan`, `Get-DMLif`,
`Get-DMFailoverGroup`, `Get-DMLLDPWorkingMode`) run as part of read-only
validation.

Network mutators (bond ports, VLANs, logical ports, failover groups, LLDP
working mode) have **no live mutation workflow by design**: they can affect
management access, data access, or failover behavior, so they are exercised by
unit tests only and surface in the live report as skipped/not executed rather
than passed. Do not add them to a workflow without following the test-owned
rules in `docs/network/safety-and-live-validation.md`.

## Output Files

The default live validation report is written to:

```text
Reports/getter-integrity-last-result.json
Reports/getter-integrity-last-result.md
```

Mutation mode additionally writes:

```text
Reports/mutation-trace-last-result.json
```

Performance runs additionally write live-confirmation artifacts (actual report
CSV headers, capacity CSV columns, NAS metric applicability, and the cleanup
registry with per-object outcome) to:

```text
Reports/performance-integrity-artifacts.json
```

Override any location when retaining multiple runs (the target directory is created if missing):

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -RunMutatingTests `
    -ReportPath './Reports/lab-report.json' `
    -MutationLogPath './Reports/lab-mutation-trace.json'
```

## Status Meanings

- `Passed`: the command completed and returned the expected result shape.
- `NoData`: the command completed successfully, but the array had no matching
  objects.
- `NotRequested`: the switch gating this check (mutation or performance) was
  not passed to the runner.
- `NotConfigured`: the switch was passed, but the related config flag
  (`AllowMutatingTests`, `Performance.Enabled`, etc.) was not enabled.
- `SkippedUnsafe`: the harness deliberately did not exercise this action —
  e.g. `Enable-`/`Disable-DMPerformanceMonitoring`, system-management
  mutators that change global, authentication, or alerting settings without
  a dedicated safe workflow, and DR commands that can change replication
  direction, site priority, or data-serving behavior whose dedicated opt-in
  flag (such as `Replication.AllowFailover` or
  `HyperMetro.AllowPrioritySwitch`) was not set. Skipped is not passed: the
  command was deliberately not exercised.
- `NotExecuted`: fallback label for a public command with no check
  representation in a read-only run.
- `Blocked`: fallback label for a public command with no check
  representation in a mutating run. This is accurate for commands with a
  genuine test-owned prerequisite that failed to materialize this run (e.g.
  Quota/QoS families), but it is currently **also** applied to opt-in
  commands (performance, history, capacity) that were simply never
  requested, since the reporting fallback cannot yet tell the two cases
  apart. If a `Blocked` performance/history/capacity command appears on a
  run that did not pass the matching `-Include*` switch, treat it as
  `NotRequested`, not as a real block — see
  [Performance integrity tests](../docs/testing/performance-integrity-tests.md#why-performance-commands-may-appear-as-notrequested-or-previously-blocked)
  for the full analysis and the proposed reporting fix (not yet implemented). Once that
  fix lands, `Blocked` will be reserved for genuine prerequisite failures.
- `Failed`: the command raised an error.
- `UnexpectedType`: returned objects did not match the expected type.

After mutation validation, confirm:

- `Failed` is `0`.
- `Blocked` is `0` for commands with a genuine test-owned prerequisite in
  this run; for opt-in performance/history/capacity commands, confirm which
  switches were actually passed before treating `Blocked` as a problem.
- `RemainingTestOwnedResources` is empty.

### System-management commands in mutating runs

No mutation workflow currently covers the system-management mutators (local
users, roles, SNMP, syslog, NTP/time). They are reported as `SkippedUnsafe`
in every run — read-only and mutating alike — because global,
authentication, and alerting mutations are not exercised by the integrity
harness unless a dedicated safe workflow exists for them. They are never
reported `Passed` and never hidden. `Set-DMdnsServer` is deliberately
excluded from live validation because DNS is a global setting with no
test-owned variant. Details and safety classification are in
`docs/system-management/safety-and-live-validation.md` and
`docs/testing/system-management-integrity-tests.md`.

## Test Layout

```text
Tests/
  Invoke-UnitTests.ps1
  TestExecutionOrder.xml
  Unit/
  Integration/
    Invoke-GetterIntegrityValidation.ps1
    IntegrityValidationConfig.psd1
    Private/
      ValidationHelpers.ps1
      ReadValidation.ps1
      MutationValidation.ps1
      Reporting.ps1
      Workflows/
```
