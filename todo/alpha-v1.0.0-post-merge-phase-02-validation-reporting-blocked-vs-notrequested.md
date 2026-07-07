# alpha-v1.0.0 Post-Merge Phase 02 — Validation Reporting: `Blocked` vs `NotRequested`

## Purpose

Implement the proposed-but-not-yet-implemented reporting-side fix so the integrity
harness no longer stamps opt-in commands (performance, history, capacity, and any other
never-requested surface) as `Blocked` on mutating runs. `Blocked` becomes reserved for
genuine test-owned prerequisite failures; a new `NotRequested` status covers commands
whose opt-in switch was absent.

## Source TODOs / evidence

- `docs/testing/performance-integrity-tests.md` § "Why performance commands may appear as
  `NotRequested` or previously `Blocked`":
  - "A reporting-side fix … is proposed but not yet implemented."
  - Root cause located at `Write-ValidationReport`
    (`Tests/Integration/Private/Reporting.ps1:126-140`): every public cmdlet not
    represented by an executed check is stamped `Blocked` on a mutating run.
- `docs/testing/integrity-tests.md` lines ~148-158 — same fallback documented as a known
  mislabel; readers told to cross-check invocation switches manually.
- `docs/testing/test-schema-organization.md` — status table lists `Blocked` as the
  coverage fallback.
- `Tests/README.md` lines ~429-449 — same caveat repeated for report readers.

Deduplication decision:
The performance "special reminder" (a 2026-07-06 run showed all 19 performance cmdlets
`Blocked` because no performance switch was passed — not a real block) is fully resolved
by this phase. No separate performance-validation phase is needed: the follow-up run with
`-IncludePerformance` already confirmed the performance machinery itself is healthy, and
the performance docs carry no other open TODO markers.

## Scope

- [Code] In `Tests/Integration/Private/Reporting.ps1`, split the coverage fallback:
  commands belonging to an opt-in domain whose switch/config gate was not passed report
  `NotRequested` (with the switch name in the message); only commands whose test-owned
  prerequisite actually failed remain `Blocked`.
- [Code] Give the report writer access to the run's requested switches
  (`-IncludePerformance`, `-IncludeExcelPerformance`, `-IncludePerformanceHistory`,
  `-IncludeCapacityHistory`, `-AllowMonitoringMutation`, `-RunMutatingTests`) so the
  distinction is computed, not inferred. Note: `-RunMutatingTests` alone must never mark
  performance commands as anything other than `NotRequested`.
- [Tests] Unit coverage for the new status routing (requested vs not-requested vs real
  prerequisite failure).
- [Docs-only] Update the four testing docs above plus `Tests/README.md` to describe the
  new `NotRequested` status and delete the "until that lands" caveats.

## Out of scope

- Running live validation. Changing any workflow's safety gating.
- Changing what `SkippedUnsafe` means anywhere.

## Implementation tasks

- [Code] Map each public command to its validation domain and opt-in gate (extend the
  existing coverage metadata rather than hardcoding name patterns where possible).
- [Code] Emit `NotRequested` with message "opt-in switch `<name>` was not passed for this
  run" for gated, unexecuted commands.
- [Tests] Pester tests against `Write-ValidationReport` with synthetic result sets:
  mutating run without performance switches → performance cmdlets `NotRequested`;
  prerequisite `NoData` case → dependents still `Blocked`.
- [Docs-only] Refresh `docs/testing/integrity-tests.md`,
  `docs/testing/performance-integrity-tests.md`, `docs/testing/test-schema-organization.md`,
  `docs/testing/system-management-integrity-tests.md`, `Tests/README.md`.
- [Safety review] Confirm the change is reporting-only: no execution-path change, no new
  REST calls.

## Files likely to inspect

- `Tests/Integration/Private/Reporting.ps1`
- `Tests/Integration/Invoke-GetterIntegrityValidation.ps1` (switch plumbing)
- `Tests/Integration/Private/PerformanceValidation.ps1` (the opt-in gate at ~:17-22)
- `Tests/ModuleCoverage.psd1`

## Files likely to modify

- `Tests/Integration/Private/Reporting.ps1`
- `Tests/Integration/Invoke-GetterIntegrityValidation.ps1`
- New/extended unit test file under `Tests/Unit/Private/`
- The five testing docs listed above

## Safety considerations

- Reporting-only change; must not alter which commands execute.
- Do not run live validation to verify — synthetic result sets in unit tests suffice;
  the next scheduled live run confirms in passing.

## Testing strategy

1. New unit tests for the status routing.
2. Full unit suite to catch report-schema assumptions elsewhere.
3. Optional read-only live run later (no mutating switches) to eyeball the report.

## Verification commands

```powershell
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
git diff --check
git diff --stat
```

## Dependencies

- Phase 01 (inventory confirms no competing plan for this fix).

## Completion criteria

- A mutating-run report with no performance switches shows performance cmdlets as
  `NotRequested`, never `Blocked`.
- `Blocked` appears only with a named failed prerequisite.
- All testing docs describe the final behavior with no "proposed fix" caveats left.

## Risks / notes

- The report schema is consumed by `Reports/getter-integrity-last-result.md` readers and
  possibly downstream tooling — keep column/status names additive.
- Harness-internal helper changes may need the dot-source whitelist in
  `Invoke-GetterIntegrityValidation.ps1` updated if new Private files are added (known
  repo quirk).
