# alpha-v1.0.0 Open Issues Phase 01 — Release Blockers: Analyzer Errors and Failing Unit Tests

**Type:** Code + Tests + Release-gate. **Live validation:** none (this phase must not connect to any array).
**Release-blocking:** YES — this is the top gate for tagging/publishing v1.0.0-alpha1.

## Purpose

Bring the release gate (`./Tests/Invoke-UnitTests.ps1 -FailOnAnalyzerIssue`) to a green
state so a real tag/publish can pass CI. Phase 11 recorded a **NO-GO**: 2 PSScriptAnalyzer
`Error`-severity findings and 39 failing Pester tests. None were introduced by Phase 11;
all were routed here (and to owning domains) rather than patched ad hoc.

## Source TODOs / evidence

- `todo/release-readiness-go-no-go.md` §3 (full analyzer + 39-test breakdown), §3c (routing),
  §10 (recommendation) — **Decision: NO-GO**.
- `docs/system-management/TODO.md` lines 61-73 — "SNMP USM user credential-parameter analyzer
  finding — release blocker, unowned".

## Current repository evidence

- **Analyzer (2 Errors):** `PSAvoidUsingUsernameAndPasswordParams` on
  `POSH-Oceanstor/Public/New-DMSnmpUsmUser.ps1:10` and
  `POSH-Oceanstor/Public/Set-DMSnmpUsmUser.ps1:10`. Full analyzer total observed at the
  Phase 11 gate run: 119 issues (93 Warning, 24 Information, 2 Error). Only the 2 Errors
  hard-fail `release.yml`'s `-FailOnAnalyzerIssue`.
- **Pester: 1193 passed / 39 failed / 0 skipped (1232 total).** Clustered by root cause in the
  go/no-go note:
  - Cluster A–C (14): pipeline/dispatch `$null`-vs-expected fixture mismatches
    (`group-membership-actions`, `HyperCDPSchedule`, `initiator-actions`, `mapping-view-actions`).
  - Cluster D (8): model-class layer (`Classes.Core/Host/Storage/Views` tests).
  - Cluster E (5): `Import-DMPerformanceReportCsv` `[System.IO.Compression.ZipFile]`
    assembly-load failures — test-environment issue, not source.
  - Cluster F (7): `Invoke-DeviceManager` / `Connect-deviceManager` parameter-contract mismatch.
  - Cluster G (4): misc single-instance (`Invoke-DMPagedRequest`, `Get-DMCapacityHistory`,
    `Get-DMPerformanceHistory`, `protection-and-consistency-groups`).
  - Cluster H (1): `Test-ModuleRequirements.Tests.ps1:20` — self-inflicted ImportExcel
    environment artifact from a prior session; no source fix.

## Scope

- Decide and apply a fix for the 2 SNMP USM analyzer Errors (see Out of scope for the caveat).
- Triage all 39 failing tests into: real regression / stale fixture / environment artifact.
- Fix stale fixtures/tests and any real regressions **within the test layer or with the owning
  domain's sign-off**; reconcile `Connect`/`Invoke-DeviceManager` tests against the current
  parameter contract.
- Fix Cluster E by loading `System.IO.Compression.FileSystem` in test/module scope before the
  `ZipFile` reference.
- Adjust Cluster H test to mock module-presence detection instead of reading real environment.

## Out of scope

- Any change to production cmdlet **behavior** beyond what a confirmed regression requires.
- The SNMP USM parameter redesign is **security-sensitive** and belongs to system-management
  ownership: this phase may implement it only with an explicit decision recorded (redesign to
  `[PSCredential]`/`SecureString` vs a justified `[Diagnostics.CodeAnalysis.SuppressMessage]`).
  Do not silently suppress without justification.
- CI YAML, signing, publishing → Phase 02.

## Implementation tasks

1. Reproduce the gate locally: `./Tests/Invoke-UnitTests.ps1 -Output Normal` (analyzer enabled).
2. SNMP USM Errors: choose redesign vs suppression; if redesign, keep the documented SNMPv3 USM
   contract intact and update the two cmdlets, their unit tests, and docs.
3. Cluster E: add `Add-Type -AssemblyName System.IO.Compression.FileSystem` (or module import)
   ahead of the `ZipFile` usage.
4. Cluster F: diff current `Connect-deviceManager.ps1` / `Invoke-DeviceManager.ps1` parameter
   sets against the tests; update whichever is stale (prefer fixing the test if the contract is
   intentional).
5. Clusters A–D, G: per-test triage; reconcile mock fixtures with current dispatch behavior.
6. Cluster H: make the test environment-independent.
7. Re-run the full gate until 0 Errors / 0 failed.

## Files likely to inspect

- `Tests/Invoke-UnitTests.ps1`, `PSScriptAnalyzerSettings.psd1`
- `Tests/Unit/Public/*Actions*.Tests.ps1`, `Tests/Unit/**/Classes.*.Tests.ps1`
- `Tests/Unit/Public/Import-DMPerformanceReportCsv.Tests.ps1`
- `Tests/Unit/**/Invoke-DeviceManager.Tests.ps1`, `Connect-deviceManager.Tests.ps1`

## Files likely to modify

- The 39 failing `*.Tests.ps1` files (and their shared helpers/fixtures).
- `POSH-Oceanstor/Public/New-DMSnmpUsmUser.ps1`, `Set-DMSnmpUsmUser.ps1` **only if** the redesign
  path is chosen and signed off.

## Safety considerations

- No live array access. No storage mutation. This is a local test/analyzer phase.
- Never print or hardcode SNMP credentials in tests; use placeholder secrets only.

## Testing strategy

- Targeted re-run of each failing test file first, then the full suite with analyzer enabled.
- For the SNMP redesign, add `-WhatIf` / contract tests proving the new parameter shape.

## Verification commands

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal            # analyzer enabled = release gate
Invoke-ScriptAnalyzer -Path .\POSH-Oceanstor -Recurse -Severity Error
```

## Dependencies

- None upstream. **Blocks Phase 02** (CI cannot go green until this is fixed) and the eventual
  tag/publish.

## Completion criteria

- `./Tests/Invoke-UnitTests.ps1 -Output Normal` reports **0 analyzer Errors and 0 test failures**.
- SNMP USM finding is either fixed or carries a reviewed, justified suppression.
- A refreshed go/no-go pass can move from NO-GO toward GO on the gate criterion.

## Risks / notes

- SNMP USM parameter redesign is a **breaking change** to those cmdlets' public parameters if
  chosen — must be called out in RELEASE_NOTES and coordinated with system-management docs.
- Cluster H is environment-only; do not "fix" source for it.
