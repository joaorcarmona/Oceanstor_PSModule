# Test Schema & Organization

How the `Tests/` folder is laid out, and how to read a validation report's
status vocabulary.

## Folder layout

```text
Tests/
  Invoke-UnitTests.ps1              # unit test runner (Pester wrapper)
  README.md                         # quick entry point
  Unit/
    Public/                         # one file per public cmdlet (or closely related group)
    Private/                        # helper functions and internal classes
  Integration/
    Invoke-GetterIntegrityValidation.ps1   # live integrity/performance runner
    IntegrityValidationConfig.psd1         # config flags (mutation + performance gates)
    Private/
      ValidationHelpers.ps1         # result/ownership/naming helpers shared by all workflows
      ReadValidation.ps1            # read-only getter checks
      MutationValidation.ps1        # mutating object workflows + excluded-commands list
      PerformanceValidation.ps1     # performance dispatcher (opt-in gate + per-stage dispatch)
      Reporting.ps1                 # JSON/Markdown report assembly + coverage fallback
      Workflows/                    # per-domain mutation/performance workflow implementations
  Reports/                          # default output location for JSON/Markdown/log files
```

## Status taxonomy

Every check the runner performs resolves to exactly one status:

| Status | Meaning | Where it comes from |
|---|---|---|
| `Passed` | Command completed and returned the expected result shape | `Add-ValidationResult` |
| `NoData` | Command completed successfully, no matching objects exist on the array | `Add-ValidationResult` |
| `NotRequested` | The switch that gates this stage was not passed to the runner | `Add-SkippedResult` (per-stage dispatch checks) |
| `NotConfigured` | The switch was passed, but the corresponding `Performance.*` or `AllowMutatingTests` config flag is not enabled | `Add-SkippedResult` |
| `SkippedUnsafe` | The harness deliberately never exercises this action regardless of switches passed (e.g. `Enable-`/`Disable-DMPerformanceMonitoring`) | `Add-SkippedResult -Status 'SkippedUnsafe'` (default) |
| `Blocked` | Fallback label for a public command with no check representation in this run, on a mutating run | `Write-ValidationReport` coverage fallback |
| `NotExecuted` | Fallback label for a public command with no check representation in this run, on a read-only run | `Write-ValidationReport` coverage fallback |
| `Failed` | The command raised an unexpected error | `Add-ValidationResult` |
| `UnexpectedType` | The command returned, but the object type(s) did not match what was expected | `Add-ValidationResult` |

## Example result interpretations

- `Get-DMSystemPerformance` is `NotRequested` → add `-IncludePerformance` to
  the invocation.
- `Get-DMPerformanceHistory` is `NotConfigured` → set
  `Performance.Enabled = $true` (and, for history/capacity specifically,
  `Performance.AllowReportTaskCreation = $true`) in
  `IntegrityValidationConfig.psd1`.
- `Set-DMPerformanceMonitoring` is `SkippedUnsafe` → this is expected unless
  `-AllowMonitoringMutation` was passed and
  `Performance.AllowMonitoringMutation = $true` is set; even then, only the
  sampling-interval round-trip runs, never the enable/disable toggle.
- A performance cmdlet shows `Blocked` on a run invoked with
  `-RunMutatingTests` but no performance switch → this is the known coverage
  fallback described in
  [Performance integrity tests](performance-integrity-tests.md#why-performance-commands-may-appear-as-notrequested-or-previously-blocked),
  not a genuine block. Treat it as `NotRequested`.
- `Get-DMQosPolicy` (or another command with a real test-owned prerequisite)
  shows `Blocked` because `New-DMQosPolicy` returned `NoData` this run → this
  is a genuine block: the prerequisite object was not available to test
  against.
- `Get-DMPortPerformance -PortType Bond` is `NoData` → expected on arrays
  with no Bond ports configured; not a failure.

## Where results are written

| Output | Default path | Set by |
|---|---|---|
| JSON report | `Reports/getter-integrity-last-result.json` | `-ReportPath` |
| Markdown summary | `Reports/getter-integrity-last-result.md` | `-MarkdownReportPath` |
| Run log | `Reports/getter-integrity-run.log` | `-RunLogPath` |
| Mutation REST trace | `Reports/mutation-trace-last-result.json` | `-MutationLogPath` |
| Performance export/scratch files | temp directory (`dm_integrity_perf_<runId>`) | `-PerformanceOutputPath` |

See [Integrity tests](integrity-tests.md#custom-report-path) for override
examples.
