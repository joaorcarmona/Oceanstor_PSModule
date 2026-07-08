# alpha-v1.0.0 Remaining Open TODOs Phase 03 — Loop-Variable Collision Audit

**Type:** Code + tests (low risk).
**Live validation allowed:** No — unit-reproducible, no live array access needed.
**Release-blocking:** No.

## Purpose

`todo/followup-name-loopvar-collision-audit.md` documents a PowerShell footgun already fixed once
in `New-DMQosPolicy`: a `foreach ($name in ...)` loop variable silently shadows a
`[Validate*]`-attributed `$Name` parameter because PowerShell variable names are case-insensitive.
Nine candidate performance getters were flagged for audit but not yet individually confirmed/fixed.
This phase formalizes that audit as a discrete, trackable unit of work.

## Source TODOs / evidence

- `todo/followup-name-loopvar-collision-audit.md` — root-cause section and the list of 9 candidate
  files (all `Get-DM*Performance.ps1` getters plus `Get-DMPerformance.ps1`), classified "lower
  risk" because they iterate `$_`, not a validated `$Name`.

## Current repository evidence

- Direct grep confirms the pattern is still present and unaudited:
  - `POSH-Oceanstor/Public/Get-DMLunPerformance.ps1:56` — `foreach ($name in $_)`
  - `POSH-Oceanstor/Public/Get-DMPerformance.ps1:85` — `foreach ($name in $_)`
- A follow-up grep for `Validate|\[string\].*\$Name|param(` in `Get-DMLunPerformance.ps1` found no
  validated `$Name` parameter in that file — confirms no active collision there today, consistent
  with the existing doc's "lower risk" classification (the loop variable shadows nothing that
  currently exists, but the pattern itself is still worth normalizing to prevent a future
  regression if a `-Name` parameter is ever added to one of these getters).
- The remaining 7 candidate files (`Get-DMControllerPerformance.ps1`, `Get-DMDiskPerformance.ps1`,
  `Get-DMHostPerformance.ps1`, `Get-DMFileSystemPerformance.ps1`, `Get-DMPortPerformance.ps1`,
  `Get-DMStoragePoolPerformance.ps1`, `Get-DMSystemPerformance.ps1`) have not yet been individually
  grepped/confirmed in this sweep — carried forward as still-open inspection items.

## Classification

Low risk, code + tests, not release-blocking.

## Scope

- Audit all 9 candidate files (the 2 confirmed above plus the 7 not yet individually checked) for
  the `foreach ($name in ...)` pattern.
- For each file where the loop variable is `$name`/`$Name` and could ever collide with a present or
  future validated parameter, rename the loop variable to something unambiguous (e.g. `$counterName`,
  `$metricName`, matching the existing fix applied to `New-DMQosPolicy`).
- Add or extend a unit test per fixed file asserting the getter still processes multiple performance
  entries correctly after the rename (regression guard, not new behavior).

## Out of scope

- Do not change any REST call shape, output class, or public parameter surface — this is a purely
  internal variable-naming safety fix.
- Do not touch mutating cmdlets — all 9 candidates are read-only `Get-DM*Performance` getters.
- No live validation required or permitted for this phase.

## Implementation tasks

1. Grep each of the 7 not-yet-checked files for `foreach ($name in` / `foreach($name in` and note
   the exact line.
2. For every confirmed occurrence (expected: all 9), rename the loop variable to a
   collision-safe name consistent with the `New-DMQosPolicy` fix.
3. Re-run/extend the corresponding unit test file for each getter to confirm behavior is unchanged.
4. Update `todo/followup-name-loopvar-collision-audit.md` to mark each file as fixed, or fold its
   remaining content into this phase file and archive the old one once all 9 are done (do not
   delete it prematurely — only once the audit is fully complete).

## Files likely to inspect

- `POSH-Oceanstor/Public/Get-DMControllerPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMDiskPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMHostPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMFileSystemPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMLunPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMPortPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMStoragePoolPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMSystemPerformance.ps1`
- `todo/followup-name-loopvar-collision-audit.md`

## Files likely to modify

- The subset of the 9 files above found to contain the pattern (expected: all 9).
- Corresponding files under `Tests/Unit/Public/*Performance*.Tests.ps1`.
- `todo/followup-name-loopvar-collision-audit.md` (status update once complete).

## Safety considerations

- None beyond normal code-review care — pure internal variable rename, no external behavior change.

## Testing strategy

- Run the targeted unit test file for each modified getter after its rename.
- Run the full unit suite once all 9 are fixed, to catch any missed cross-reference.

## Verification commands

```powershell
Select-String -Path POSH-Oceanstor/Public/Get-DM*Performance.ps1 -Pattern 'foreach\s*\(\s*\$name\s+in'
& "C:\tools\rtk\rtk.exe" dotnet test  # or the project's Pester invocation, e.g.:
# ./Tests/Invoke-UnitTests.ps1 -Output Normal
```

## Dependencies

- None — self-contained, no dependency on other phases.

## Completion criteria

- All 9 files confirmed either fixed or confirmed not to contain the pattern; loop-var audit doc
  updated/archived; targeted unit tests green.

## Risks / notes

- Low risk. Purely defensive renaming; the current classification is correct that no active
  collision exists today, but the fix prevents a silent regression if a validated `-Name` parameter
  is ever added to one of these getters later.
