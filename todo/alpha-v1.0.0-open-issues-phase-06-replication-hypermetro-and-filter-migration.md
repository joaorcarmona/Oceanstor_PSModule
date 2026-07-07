# alpha-v1.0.0 Open Issues Phase 06 — Replication / HyperMetro Carry-Over + Server-Side Filter Migration

**Type:** Code + Tests (+ Live-validation planning for deferred DR runs). **Live validation:** none
executed here — dual-array and failover/switchover runs are deferred to supervised sessions.
**Release-blocking:** NO.

## Purpose

Close the additive DR carry-over gaps (endpoint wrappers, a getter, force-start coverage) and the
cross-domain server-side `filter=` migration, while keeping the genuinely blocked/deferred DR items
(batch ops, dual-array NAS, failover/switchover) tracked with their blockers.

## Source TODOs / evidence

- `docs/replication-hypermetro/TODO.md`:
  - Low Priority — dedicated wrappers for `REPLICATIONPAIR/transfer` and `modifyPreferredPolicy`
    (instead of `-ApiProperties` passthrough); `Set-DMVStorePair`; a file-system-filtered
    replication-pair getter; **server-side `filter=` on DR getters (currently client-side)**.
  - Testing — optional HyperMetro **force-start** coverage on a test-owned pair behind its own
    opt-in flag (currently not exercised).
  - Medium Priority — **batch operations deferred (no documented REST endpoint)**.
  - Testing (Deferred) — **NAS/vStore dual-array lab** workflows; **failover/switchover** dedicated
    per-operation flag + human-supervised run.
  - Future — remote LUN rescan (`remote_lun/scan_remote_lun`), DR dashboards/reporting.
- Cross-domain filter item corroborated by the network TODO (getters filter client-side) —
  server-side `filter=` is the shared correctness/perf improvement.

## Current repository evidence

- 62 DR cmdlets shipped (after `Get-DMQuorumServer`); all 52 mutators have `-WhatIf` no-API-call
  coverage (`Tests/Unit/Public/replication-hypermetro-whatif.Tests.ps1`) and `ConfirmImpact=High`
  on modify/remove/transition.
- DR getters currently apply name filtering **client-side** (per TODO Low Priority).
- Replication/HyperMetro mutation workflows + gates exist and default off; their first live run is
  Phase 03 (SAN pair) / this phase's deferred items (dual-array, failover/switchover).

## Scope

- Implement dedicated wrappers: `REPLICATIONPAIR/transfer`, `modifyPreferredPolicy`, `Set-DMVStorePair`.
- Add the file-system-filtered replication-pair getter.
- Migrate DR getters (and other identified `Get-DM*` getters) to server-side `filter=` where the
  REST API documents it; fall back to client-side only where it does not.
- Add opt-in HyperMetro force-start unit + gated-workflow coverage (default off).

## Out of scope

- **DR batch operations** — blocked (no documented per-object batch endpoint); do not guess bodies.
- **NAS/vStore dual-array** and **failover/switchover** live runs — deferred (require a dual-array
  lab and dedicated per-operation flags + human supervision). Track only; execute under a supervised
  session like Phase 03.
- Remote LUN rescan and DR dashboards — future feature branches (retain for planning).

## Implementation tasks

1. Add `Set-DMVStorePair` and the `transfer` / `modifyPreferredPolicy` wrappers with
   `SupportsShouldProcess` + appropriate `ConfirmImpact`, mock unit tests, `-WhatIf` coverage.
2. Add the file-system-filtered replication-pair getter (read-only), register in read validation.
3. Filter migration: for each getter where the REST reference documents `filter=`, send it
   server-side; unit-test that the request carries the filter (not post-filtered in PowerShell).
4. HyperMetro force-start: add a gated (default-off) workflow step + unit coverage for a test-owned
   pair only.

## Files likely to inspect

- `POSH-Oceanstor/Public/*ReplicationPair*.ps1`, `*HyperMetro*.ps1`, `*VStorePair*.ps1`
- DR getters (`Get-DMReplicationPair`, `Get-DMHyperMetroPair`, etc.)
- `Tests/Integration/Private/ReadValidation.ps1`, DR workflow files, `IntegrityValidationConfig.psd1`
- `OceanStor Dorado 6.1.6 REST Interface Reference.md` (targeted `filter=` / `transfer` lookups)

## Files likely to modify

- New `Set-DMVStorePair.ps1` + wrappers; DR getters (filter migration); new getter; their unit tests;
  read-validation registration; ModuleCoverage/manifest exports for any new cmdlet.

## Safety considerations

- New wrappers are mutators → `SupportsShouldProcess`, correct `ConfirmImpact`, mock-only unit tests,
  `SkippedUnsafe`/gated in live validation. Never run against pre-existing DR objects.

```powershell
# deferred DR live runs (dual-array / failover-switchover) — internal planning reference only
$storageIP = '10.10.10.24'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
# -SkipCertificateCheck ; operator supplies RemoteDeviceId/RemoteLunId/DomainId at run time
```

## Testing strategy

- Mock-based unit tests for every new cmdlet + filter-migration assertions.
- `-WhatIf` no-API-call proof for new mutators. No live execution in this phase.

## Verification commands

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal
Select-String -Path .\POSH-Oceanstor\Public\Get-DMReplicationPair.ps1 -Pattern 'filter='
```

## Dependencies

- New exports must be added to `POSH-Oceanstor.psd1` and `Tests/ModuleCoverage.psd1` (keep in sync).
- Dual-array / failover-switchover execution depends on a dual-array lab + supervised session.

## Completion criteria

- `Set-DMVStorePair` + transfer/preferred-policy wrappers + FS-filtered getter shipped, unit-tested,
  exported, read-validation-registered where read-only.
- Identified getters use server-side `filter=` where documented.
- Force-start covered behind an opt-in default-off gate.
- Batch / dual-array / failover-switchover remain tracked-deferred with blockers intact.

## Risks / notes

- New mutators widen the DR mutation surface — keep the test-owned + `ConfirmImpact=High` discipline
  identical to the existing DR cmdlets.
