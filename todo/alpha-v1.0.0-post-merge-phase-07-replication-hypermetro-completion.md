# alpha-v1.0.0 Post-Merge Phase 07 — Replication and HyperMetro Completion

## Purpose

Complete the stabilization of the 61-cmdlet DR surface: put the DR getters into standing
live read validation, extend `-WhatIf` unit coverage from 1 to all 52 DR mutators, add
the quorum-server inventory getter, and prepare (not run) the gated lab mutation
validation that the initial branch could not perform for lack of a configured remote
array. DR is the most safety-sensitive domain in the module.

## Source TODOs / evidence

- `docs/replication-hypermetro/TODO.md` § High Priority — both verified still open:
  - DR getters (`Get-DMRemoteDevice`, `Get-DMReplicationPair`,
    `Get-DMReplicationConsistencyGroup`, `Get-DMHyperMetroDomain`, `Get-DMHyperMetroPair`,
    `Get-DMHyperMetroConsistencyGroup`, `Get-DMVStorePair`, `Get-DMFileHyperMetroDomain`,
    guarded `Get-DMRemoteLun`) absent from
    `Tests/Integration/Private/ReadValidation.ps1` — confirmed by grep: none registered.
  - "Run the gated Replication and HyperMetro mutation workflows against a configured
    remote-array lab pair … (no lab remote configuration was available for the initial
    branch validation)."
- § Medium Priority: "today only `New-DMReplicationPair` has an explicit
  no-API-call-under-WhatIf test" — confirmed: only
  `replication-hypermetro-pair-lifecycle.Tests.ps1` contains WhatIf assertions; batch
  endpoints; quorum server inventory cmdlet; enum/status translation.
- § Low Priority: `transfer`/`modifyPreferredPolicy` wrappers, `Set-DMVStorePair`,
  server-side `filter=` on DR getters, pipeline-input assertions.
- § Testing: optional force-start coverage; NAS/vStore gated workflows (needs dual-array
  NAS lab); failover/switchover coverage behind `Replication.AllowFailover` /
  `HyperMetro.AllowPrioritySwitch`.
- `docs/replication-hypermetro/safety-and-live-validation.md` — sync/split/switch/
  failover/priority ops `SkippedUnsafe` without per-operation flags.

Deduplication decision:
The `-WhatIf` assertion helper is shared with Phase 06 (network) — build once, consume
in both. Server-side `filter=` work on DR getters follows the exact same `::`/`:`
convention established module-wide; it is planned here (domain owner), not in a generic
consistency phase. The memory-noted "Get-DM* getters still filtering client-side"
enhancement list overlaps — the DR getters' slice of that list is owned by this phase.

## Scope

- [Code] Register all nine DR getters in `ReadValidation.ps1` with expected output
  types; `Get-DMRemoteLun` guarded (only runs when a remote device exists, tolerates
  empty results).
- [Tests] Extend the shared WhatIf pattern across all remaining DR mutators
  (~51), ideally one `-ForEach`-driven spec per test file.
- [Code] Quorum server inventory getter (e.g. `Get-DMQuorumServer`) so
  `Add-DMQuorumServerToHyperMetroDomain -QuorumServerId` resolves without DeviceManager
  UI — confirm the endpoint in the REST reference first.
- [Code] Batch operations: array parameters on existing lifecycle cmdlets for
  `REPLICATIONPAIR/*/batch`, `HyperMetroPair/*/batch`, `ADD_MIRROR/DEL_MIRROR/batch`.
- [Code] Enum/status translation audit on DR classes against the 6.1.6 enum tables;
  translate raw codes still surfaced.
- [Tests] Pipeline-input assertions for `-Id`-by-property-name lifecycle cmdlets.
- [Live-validation planning] Written plan for the gated lab-pair mutation run
  (replication pair lifecycle, HyperMetro pair lifecycle on test-owned LUNs), including
  remote-array prerequisites, config flags, and expected `SkippedUnsafe` set. Internal
  planning may reference `$storageIP = '10.10.10.24'`; do not run.
- [Docs-only] Refresh topic-page examples with captured output *after* the lab run
  happens; add the "planned failover runbook" example (split → switch → resync) only
  after live switchover validation — until then keep as placeholders in TODO.

## Out of scope

- Automatic failover/switchover/priority switching without their dedicated per-operation
  config flags — permanently.
- Harness-driven mutation of HyperMetro domains or quorum associations (workflow
  consumes a configured existing domain only, read-only with respect to the domain).
- NAS/vStore gated workflows until a dual-array NAS lab exists (planning note only).
- Low-priority wrappers (`transfer`, `modifyPreferredPolicy`, `Set-DMVStorePair`) unless
  they fall out trivially from batch work.

## Implementation tasks

- [Code] `ReadValidation.ps1` entries + `ModuleCoverage.psd1` class checks for the nine
  getters; guarded remote-LUN logic.
- [Tests] WhatIf `-ForEach` spec across the five
  `replication-hypermetro-*.Tests.ps1` files.
- [Code] `Get-DMQuorumServer` (+ class, export, coverage registration, unit tests).
- [Code] Batch parameters with per-item error semantics consistent with the module's
  pipeline continue-on-error convention.
- [Safety review] Confirm every DR mutator retains `SupportsShouldProcess` +
  `ConfirmImpact = 'High'` and string-form `[OutputType(...)]`.
- [Live-validation planning] Lab-pair runbook with the full test-owned-object rules.
- [Docs-only] Update `docs/replication-hypermetro/TODO.md` and touched topic pages.

## Files likely to inspect

- `Tests/Integration/Private/ReadValidation.ps1`, `Workflows/` DR workflow files
- `POSH-Oceanstor/Public/*Replication*`, `*HyperMetro*`, `*VStorePair*`, `*RemoteDevice*`,
  `*RemoteLun*`, `*Quorum*`
- `Tests/Unit/Public/replication-hypermetro-*.Tests.ps1`
- `OceanStor Dorado 6.1.6 REST Interface Reference.md` (quorum, batch, enum tables)

## Files likely to modify

- `ReadValidation.ps1`, `ModuleCoverage.psd1`, five DR unit-test files
- New `Get-DMQuorumServer.ps1` + class; batch-parameter edits on lifecycle cmdlets
- `POSH-Oceanstor.psd1` (new export)
- `docs/replication-hypermetro/TODO.md` and affected topic pages

## Safety considerations

- Read-only getter registration is the only live-facing change this phase makes; remote
  LUN queries must tolerate absent remote configuration gracefully.
- Never mutate pre-existing DR objects during validation, ever. Sync/split/switch/
  failover/priority/secondary-access changes remain behind per-operation flags and are
  `SkippedUnsafe` by default.
- Batch parameters multiply blast radius: `ShouldProcess` messages must enumerate the
  IDs affected, and unit tests must assert per-item error isolation.

## Testing strategy

1. Unit: WhatIf sweep, new getter tests, batch-parameter tests; full suite green.
2. Static: ScriptAnalyzer on changed files; `Import-Module` smoke for OutputType
   resolution.
3. Next scheduled read-only live run exercises the newly registered getters.
4. Gated mutation run happens only when the remote lab pair is configured, per runbook.

## Verification commands

```powershell
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
Get-Command -Module POSH-Oceanstor
git diff --check; git diff --stat
```

## Dependencies

- Phase 01. Phase 02 (correct labeling of never-requested DR mutators). WhatIf helper
  shared with Phase 06 — coordinate which lands first.

## Completion criteria

- All nine DR getters registered and passing in a read-only live run.
- Every DR mutator has WhatIf unit coverage.
- Quorum inventory getter shipped; batch parameters shipped or explicitly deferred with
  reasons; lab-pair runbook written.

## Risks / notes

- `Get-DMRemoteLun` against an array with no remote devices may error rather than return
  empty — the guard must handle both shapes.
- Enum translation must come from the 6.1.6 tables, not inference; wrong health/status
  translation in a DR domain is worse than a raw code.
