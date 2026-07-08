# Replication and HyperMetro TODO

## Current Focus

- Stabilize the shipped DR surface (62 cmdlets after `Get-DMQuorumServer`):
  documentation, live read-only coverage, and the opt-in lab mutation
  workflows.

## Recently Completed

- **Phase 07 (2026-07-07):** Registered all nine DR getters
  (`Get-DMRemoteDevice`, `Get-DMReplicationPair`,
  `Get-DMReplicationConsistencyGroup`, `Get-DMHyperMetroDomain`,
  `Get-DMHyperMetroPair`, `Get-DMHyperMetroConsistencyGroup`,
  `Get-DMVStorePair`, `Get-DMFileHyperMetroDomain`, and the guarded
  `Get-DMRemoteLun`) plus the new `Get-DMQuorumServer` in
  `Tests/Integration/Private/ReadValidation.ps1`. `Get-DMRemoteLun` is
  guarded: it only runs when a replication-type remote device exists and is
  otherwise reported `NotConfigured`, never a failure.
- **Phase 07:** Systematic `-WhatIf` no-API-call coverage across all 52 DR
  mutators via a single `-ForEach` spec
  (`Tests/Unit/Public/replication-hypermetro-whatif.Tests.ps1`) driving the
  shared `Tests/Unit/Support/Assert-DMWhatIfSafe.ps1` helper, plus a
  `ConfirmImpact = High` assertion for every in-place modify/remove/transition.
- **Phase 07:** New `Get-DMQuorumServer` read-only inventory getter
  (`OceanStorQuorumServer` class) backed by the documented `QuorumServer`
  collection resource (REST §4.9.8), so `-QuorumServerId` for
  `Add-DMQuorumServerToHyperMetroDomain` can be resolved without DeviceManager.
- **Phase 07:** Pipeline-input assertions proving `Get-DMReplicationPair |
  Sync/Split/Switch-DMReplicationPair` and `Get-DMHyperMetroPair |
  Sync/Suspend-DMHyperMetroPair` bind `-Id` by property name while
  `ShouldProcess` still gates the mutation.
- **Phase 07:** DR enum/status translation audit against the 6.1.6 enum tables
  (see [safety-and-live-validation.md](safety-and-live-validation.md) §Enum
  audit).
- SAN DR surface: replication pairs, replication consistency groups,
  HyperMetro domains (including quorum association), HyperMetro pairs, and
  HyperMetro consistency groups.
- NAS/vStore tranche: vStore pairs, file-system replication pair creation and
  secondary protection, and file-system HyperMetro domains.
- Typed output classes, table format views, manifest exports, and focused
  unit tests across the DR test files.
- Opt-in integration workflows with `NotConfigured`/`SkippedUnsafe` gating and
  ID-based cleanup.
- Fixed class-literal `[OutputType([...])]` attributes (string form now) so DR
  cmdlets work from a normal `Import-Module` session; verified read-only
  against a lab array. The same fix was applied module-wide (QoS, quota, and
  HyperCDP schedule cmdlets had the identical defect).

## High Priority

- **Deferred — requires human-supervised live run.** Run the gated Replication
  and HyperMetro mutation workflows against a configured remote-array lab pair
  and record the results. The workflow harness, config gates
  (`Replication.*`, `HyperMetro.*`), and ID-based cleanup are all in place, but
  execution is blocked pending an operator supplying the lab-specific
  `RemoteDeviceId`/`RemoteLunId`/`DomainId` and reviewing the intended config
  before a supervised run. See the
  [lab-pair mutation runbook](safety-and-live-validation.md#lab-pair-mutation-runbook).
  Discovering and populating those IDs unattended is explicitly out of scope
  (it risks touching pre-existing DR objects).
  - **Status (Phase 03, 2026-07-07): Deferred — not run.** No operator-supplied
    `RemoteDeviceId`/`RemoteLunId`/`DomainId` were provided, and the 2026-07-07
    supervised session's single mutation gate was spent on the SystemManagement
    SNMP-trap surface. `Replication.*` and `HyperMetro.*` gates stayed **off**.
    Blocker unchanged: operator must supply the lab-pair IDs and review the config
    before a dedicated single-gate supervised run.

## Medium Priority

- **Deferred — no documented REST endpoint.** Batch operations
  (`REPLICATIONPAIR/*/batch`, `HyperMetroPair/*/batch`,
  `ADD_MIRROR/DEL_MIRROR/batch`) as array parameters on the lifecycle cmdlets.
  The 6.1.6 REST reference documents no per-object DR batch endpoint (grep of
  the reference returns no `ADD_MIRROR`/`DEL_MIRROR`/`*/batch` interface for
  `REPLICATIONPAIR` or `HyperMetroPair`). Batch multiplies blast radius, so
  this stays deferred until a documented endpoint exists rather than guessing
  one. Re-open only with a confirmed reference section.

## Low Priority / Polish

- _Done (Phase 06)._ Dedicated wrappers `Set-DMReplicationPairMode`
  (`REPLICATIONPAIR/transfer`) and `Set-DMHyperMetroPairPreferredPolicy`
  (`HyperMetroPair/MODIFY_PREFERRED_POLICY`) replace `-ApiProperties`
  passthrough for those endpoints.
- _Done (Phase 06)._ `Set-DMVStorePair` (`VSTORE_PAIR/change_ip_work_mode`)
  and `Get-DMFileSystemReplicationPair` (server-side `filter=LOCALRESID`)
  shipped, unit-tested, and read-validation-registered.
- Server-side `filter=` on DR getters where the REST API documents it:
  - _Done._ `Get-DMFileSystemReplicationPair` (`filter=LOCALRESID`) and
    `Get-DMVStorePair` (`filter=REPTYPE`) request server-side.
  - _Retained client-side (documented fallback)._ `Get-DMReplicationPair` and
    `Get-DMHyperMetroPair` `-Name` matches three fields (local name, remote
    name, id); no single documented server-side filter field covers all three,
    so a single-field server filter would drop valid matches. `Get-DMQuorumServer`
    documents only `range`, no `filter`.

## Testing and Validation

- _Done (Phase 06)._ HyperMetro force-start coverage on a test-owned pair sits
  behind the default-off `HyperMetro.AllowForceStart` gate (workflow step is
  `SkippedUnsafe` when off; command behavior is unit-tested). The gate is
  independent of failover/switchover gates and is never enabled in committed
  config — a live force-start run stays deferred to a supervised session.
- **Deferred — requires dual-array NAS lab.** Gated workflows for the
  NAS/vStore tranche (vStore pair lifecycle, file-system replication pair
  lifecycle).
- **Deferred — requires dedicated per-operation flag + human-supervised run.**
  Failover/switchover integration coverage in a dedicated DR exercise window
  (`Replication.AllowFailover`, `HyperMetro.AllowPrioritySwitch`). These stay
  `SkippedUnsafe` by default and are never run against pre-existing objects.

## Documentation

- Refresh topic-page examples with real captured output once the lab mutation
  workflows have run end to end.
- Add a worked "planned failover runbook" example (split → switch → resync)
  after live switchover validation.

## Future Feature Branches

- Remote LUN rescan (`remote_lun/scan_remote_lun`) and remote device link
  management.
- DR dashboards/reporting: pair health rollups via the existing report
  template system.

## Not Planned / Unsafe by Default

- Automatic failover, switchover, or priority switching without the dedicated
  per-operation config flags.
- Harness-driven mutation of HyperMetro domains or quorum associations (the
  workflow consumes a configured existing domain only).
- Any mutation of pre-existing DR objects during validation, ever.

## Notes for Contributors

- Use string-form `[OutputType('OceanstorX')]` — class literals do not
  resolve from a normal module import.
- Every DR mutator must keep `SupportsShouldProcess` and
  `ConfirmImpact = 'High'`.
- New getters need: an entry in `FunctionsToExport`, class registration in
  `Tests/ModuleCoverage.psd1`, unit coverage in the appropriate
  `replication-hypermetro-*.Tests.ps1` file, and (for live coverage) an entry
  in `ReadValidation.ps1`.
- Follow the safety rules in
  [safety-and-live-validation.md](safety-and-live-validation.md) for any live
  testing.
