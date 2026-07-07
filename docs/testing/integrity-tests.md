# Integrity Tests

Live validation against a real OceanStor array via
`Tests/Integration/Invoke-GetterIntegrityValidation.ps1`. Covers getter
correctness (object shapes, filtering) and, opt-in, test-owned mutation
workflows (create/update/delete cycles the harness fully owns and cleans up).

Performance/capacity checks are a separate opt-in layer — see
[Performance integrity tests](PERFORMANCE-INTEGRITY-TESTS.md).

## Purpose

- Confirm every public getter returns the expected object type(s) against a
  real array.
- Confirm mutation workflows (LUN, LUN group, protection, QoS, host, NAS,
  mapping, initiators, quota, HyperCDP schedule) round-trip correctly when
  explicitly requested.
- Produce a machine-readable JSON report and a human-readable Markdown
  summary after every run.

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

> **Note on `Blocked` vs `NotRequested`:** as of this writing, the reporting
> fallback in `Tests/Integration/Private/Reporting.ps1` labels *every*
> public command with no matching check as `Blocked` on a mutating run (even
> if the real reason is simply that an opt-in switch, such as a performance
> switch, was never passed) or `NotExecuted` on a read-only run. See
> [Performance integrity tests — why performance commands may appear as NotRequested](PERFORMANCE-INTEGRITY-TESTS.md#why-performance-commands-may-appear-as-notrequested-or-previously-blocked)
> and
> [`PERFORMANCE/INTEGRITY-BLOCKED-COMMANDS-PLAN.md`](../../PERFORMANCE/INTEGRITY-BLOCKED-COMMANDS-PLAN.md)
> for the full analysis and the proposed reporting-side fix. `Blocked` should
> be trusted at face value only for commands with a genuine test-owned
> prerequisite in this run (Quota, QoS families) — for opt-in domains like
> performance, check which switches were actually passed before treating
> `Blocked` as a real problem.

For a mutating run, confirm:

- `Failed` is `0`.
- `Blocked` is `0`, unless a prerequisite was intentionally unavailable on the array.
- `RemainingTestOwnedResources` is empty.
