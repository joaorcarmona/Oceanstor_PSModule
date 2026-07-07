# Live Validation Safety

What is and isn't safe to run against a live array, and how the harness
enforces it.

## Read-only vs query-style POST vs mutation POST

Not every `POST` request is a mutation. The REST-based DeviceManager API uses
`POST` for some read/query operations as well as for creates:

- **Read-only `GET`**: standard object retrieval — always safe, never
  audited for mutation.
- **Query-style `POST`**: a `POST` used to submit a query body (e.g.
  `POST performance_data` for batch performance metric retrieval) — no
  object is created or changed on the array. These are explicitly
  allowlisted in `Assert-PerformanceTraceReadOnly` so the trace audit does
  not flag them as unexpected mutations.
- **Mutation `POST`/`PUT`/`PATCH`/`DELETE`**: creates, updates, or removes an
  object (LUN, LUN group, report task, etc.). These only occur inside
  mutating workflows, and only against resources the harness itself created
  and registered this run.

Every mutating run ends with a trace audit that inspects the full captured
REST request log and fails loudly if any request outside the expected,
allowlisted set was made.

## Report-task controlled mutation

Performance history and capacity checks are the one performance area that
creates real objects on the array (report tasks):

1. A baseline snapshot of all existing report tasks is captured before
   anything runs.
2. Each report task the harness creates is registered immediately after
   creation, keyed by its captured ID.
3. Cleanup deletes strictly by that captured ID — never by name, and never
   any ID present in the pre-run baseline.
4. `-KeepCreatedReportTasks` skips cleanup deliberately, for inspecting the
   created task before it's removed.

This mirrors the same ownership discipline used for mutating integrity
resources (LUNs, LUN groups, etc.) — see
[Integrity tests — ownership model and cleanup](INTEGRITY-TESTS.md#ownership-model-and-cleanup).

## Monitoring mutation double gate

The only performance check that changes a live setting (rather than creating
a temporary object) is the sampling-interval round-trip:

1. Runner switch: `-AllowMonitoringMutation`.
2. Config flag: `Performance.AllowMonitoringMutation = $true`.

Both must be set. The workflow captures the original
`SamplingIntervalSeconds` value first, changes it, verifies the change, and
restores the original value in a `finally` block — even if the verification
step fails. If the restore itself fails, the check fails loudly and the exact
manual restore command is printed as a warning so you can fix it by hand.

`Enable-DMPerformanceMonitoring` / `Disable-DMPerformanceMonitoring` are
never exercised under any switch combination — toggling the master
collection switch resets the array's collection begin time, which is not a
safe, restorable action. These always report `SkippedUnsafe`.

## Test-owned naming and cleanup by captured ID

Every object a mutating or performance workflow creates uses a predictable,
namespaced name (`New-TestName` / `New-ReportTaskName`, using
`IntegrityValidationConfig.psd1`'s `NamePrefix`, default `dm_integrity`), and
is registered in an ownership registry the moment its ID is captured from the
create response.

- Any write (update, rename, remove) first asserts the target is registered
  as owned by this run.
- Cleanup runs in reverse dependency order, using the resource's current
  (possibly renamed) identity, and only ever deletes by the captured ID —
  never by matching name or type alone.
- Anything left registered when the run ends (e.g. because cleanup itself
  failed) is reported under `RemainingTestOwnedResources` in both the JSON
  and Markdown reports, so it's visible and can be cleaned up manually.

## Checking for performance report-task residue

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred -SkipCertificateCheck:$true

Get-DMPerformanceReportTask | Where-Object { $_.Name -like 'dm_integrity_*' }
```

If this returns any tasks after a run completed normally (not interrupted),
compare against `RemainingTestOwnedResources` in the Markdown report before
removing them manually.

## Safe staged validation order

Run each stage independently before combining switches, so a failure is easy
to attribute to a single new capability:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

# 1. Read-only getters
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 -Hostname $storageIP -Credential $cred -SkipCertificateCheck

# 2. Realtime performance (requires Performance.Enabled = $true)
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 -Hostname $storageIP -Credential $cred -SkipCertificateCheck -IncludePerformance

# 3. Mutating integrity (requires AllowMutatingTests = $true)
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 -Hostname $storageIP -Credential $cred -SkipCertificateCheck -RunMutatingTests

# 4. Performance history / capacity (requires Performance.AllowReportTaskCreation = $true)
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 -Hostname $storageIP -Credential $cred -SkipCertificateCheck -IncludePerformanceHistory -IncludeCapacityHistory

# 5. Monitoring mutation, only if specifically needed (requires Performance.AllowMonitoringMutation = $true)
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 -Hostname $storageIP -Credential $cred -SkipCertificateCheck -IncludePerformance -AllowMonitoringMutation
```

See also [Performance integrity tests](PERFORMANCE-INTEGRITY-TESTS.md) and
[Integrity tests](INTEGRITY-TESTS.md) for the full switch/config reference
for each stage.
