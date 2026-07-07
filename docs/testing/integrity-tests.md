# Integrity Tests

Live validation against a real OceanStor array via
`Tests/Integration/Invoke-GetterIntegrityValidation.ps1`. Covers getter
correctness (object shapes, filtering) and, opt-in, test-owned mutation
workflows (create/update/delete cycles the harness fully owns and cleans up).

Performance/capacity checks are a separate opt-in layer — see
[Performance integrity tests](performance-integrity-tests.md).

## Purpose

- Confirm every public getter returns the expected object type(s) against a
  real array.
- Confirm mutation workflows (LUN, LUN group, protection, QoS, host, NAS,
  mapping, initiators, quota, HyperCDP schedule) round-trip correctly when
  explicitly requested.
- Produce a machine-readable JSON report and a human-readable Markdown
  summary after every run.

## Storage Domain Coverage

| Domain | Read-only validation | Mutating workflow |
|---|---|---|
| Block storage | `Get-DMlun`, `Get-DMstoragePool`, host/host-group getters, LUN groups, mapping views, initiators, protection groups | Test-owned LUN, LUN group, host, host group, mapping/direct mapping, initiator, protection, HyperCDP schedule workflows |
| File storage | `Get-DMFileSystem`, `Get-DMShare` for NFS/CIFS, `Get-DMnfsFileClient`, file-system snapshots, quotas | Test-owned file system, dTree, NFS share/client, CIFS share, file-system snapshot, quota workflows |
| QoS | `Get-DMQosPolicy` | Test-owned SmartQoS policy lifecycle, enable/disable, update, and LUN-group association |
| Snapshots | `Get-DMLunSnapshot`, `Get-DMFileSystemSnapshot`, `Get-DMSnapshotConsistencyGroup`, `Get-DMHyperCDPSchedule` | Test-owned LUN snapshots, file-system snapshots, snapshot consistency groups, snapshot copies, and HyperCDP schedules |

The mutation workflows require `-RunMutatingTests`,
`AllowMutatingTests = $true`, and the relevant per-domain config gate. Quota
and QoS checks can report `Blocked` when their test-owned prerequisites do not
materialize; unsafe operations report `SkippedUnsafe`.

## Connection parameters

| Parameter | Purpose |
|---|---|
| `-Hostname` (mandatory) | Array address or FQDN |
| `-Credential` | A `[pscredential]`. If omitted, `Connect-deviceManager -Secure` prompts interactively. Never read from or written to the configuration file. |
| `-SkipCertificateCheck` | Skip TLS certificate validation (lab arrays with self-signed certs) |
| `-ConfigurationPath` | Path to the config `.psd1` (default: `Tests/Integration/IntegrityValidationConfig.psd1`) |
| `-NoProgress` | Suppress the interactive `Write-Progress` display (useful when redirecting output) |
| `-ShowTestExecution` | Print a persistent line per completed check in addition to progress |

## Read-only getter mode (default)

With no mode switches, the runner only calls `Get-*`/list cmdlets — no
resources are created, modified, or removed.

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck
```

## Mutating mode

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -RunMutatingTests
```

Mutating mode requires **both**:

1. `AllowMutatingTests = $true` in `Tests/Integration/IntegrityValidationConfig.psd1`.
2. The runner called with `-RunMutatingTests`.

If either is missing, the mutation workflows are skipped and reported with a
`NotRequested`/`NotConfigured` status rather than run.

Optional: run the extra multi-LUN pipeline batch coverage (creates three
additional test-owned LUNs; can add noticeable runtime on arrays where LUN
create/remove is slow):

```powershell
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -RunMutatingTests `
    -RunPipelineBatchCoverage
```

(Equivalent to setting `LunGroup.EnablePipelineBatchCoverage = $true` in the
config permanently.)

## Ownership model and cleanup

- Every resource created by a mutating workflow is registered in an
  in-memory ownership registry (`Register-TestOwnedResource`) immediately
  after the create call returns, keyed by kind + captured identity.
- Update/rename/remove calls first assert the target is registered
  (`Assert-TestOwnedResource`) — the harness refuses to touch anything it did
  not create this run.
- Cleanup runs resources in reverse dependency order using their current
  (possibly renamed) identity, then unregisters them
  (`Complete-TestOwnedResource`).
- Any resource left registered at the end of the run is reported under
  `RemainingTestOwnedResources` in both the JSON and Markdown reports.

## Custom report path

`-ReportPath` and related output-path parameters are supported directly on
the runner:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -ReportPath .\Reports\getter-integrity-manual.json
```

Related output-path parameters:

| Parameter | Default | Purpose |
|---|---|---|
| `-ReportPath` | `Reports/getter-integrity-last-result.json` | Machine-readable JSON report |
| `-MarkdownReportPath` | `Reports/getter-integrity-last-result.md` | Human-readable Markdown summary |
| `-RunLogPath` | `Reports/getter-integrity-run.log` | Per-command invocation log |
| `-MutationLogPath` | `Reports/mutation-trace-last-result.json` | REST request/response trace for mutating runs |

Override multiple output locations at once when you want to retain several
runs side by side:

```powershell
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -RunMutatingTests `
    -ReportPath '.\Reports\lab-report.json' `
    -MutationLogPath '.\Reports\lab-mutation-trace.json'
```

## Status meanings

| Status | Meaning |
|---|---|
| `Passed` | Command completed and returned the expected result shape. |
| `NoData` | Command completed successfully, but no matching objects exist on the array. |
| `NotRequested` | The switch that gates this check was not passed to the runner. |
| `NotConfigured` | The switch was passed, but the corresponding config flag in `IntegrityValidationConfig.psd1` is not enabled. |
| `SkippedUnsafe` | The harness deliberately never exercises this action (e.g. toggling a global monitoring switch) regardless of switches passed. |
| `Blocked` | A test-owned prerequisite resource this run needed was not created successfully (e.g. `New-DMQosPolicy` returned `NoData`, so its dependent setters cannot run). |
| `NotExecuted` | Fallback status for a public command with no representation in this run's checks, when the run was read-only (no `-RunMutatingTests`). |
| `Failed` | The command raised an unexpected error. |
| `UnexpectedType` | The command returned, but the object type(s) did not match what was expected. |

> **Note on `Blocked` vs `NotRequested`:** the reporting fallback in
> `Tests/Integration/Private/Reporting.ps1` routes public commands with no
> matching check by opt-in domain. Commands that belong to a gated domain
> (performance, performance history, capacity history, Excel performance,
> monitoring mutation) are labeled `NotRequested` when their runner switch
> was not passed, even on a mutating run — `-RunMutatingTests` alone never
> requests those domains. `Blocked` is reserved for commands whose domain
> *was* requested but a genuine test-owned prerequisite in this run was
> unavailable (e.g. `New-DMQosPolicy` returned `NoData`, so its dependent
> setters cannot run). See
> [Performance integrity tests — why performance commands may appear as NotRequested](performance-integrity-tests.md#why-performance-commands-may-appear-as-notrequested-or-previously-blocked)
> for the full domain-to-switch mapping.

For a mutating run, confirm:

- `Failed` is `0`.
- `Blocked` is `0`, unless a prerequisite was intentionally unavailable on the array.
- `RemainingTestOwnedResources` is empty.
