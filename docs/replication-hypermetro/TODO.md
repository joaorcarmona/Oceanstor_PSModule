# Replication and HyperMetro TODO

## Current Focus

- Stabilize the newly shipped 61-cmdlet DR surface: documentation, live
  read-only coverage, and the opt-in lab mutation workflows.

## Recently Completed

- SAN DR surface: replication pairs, replication consistency groups,
  HyperMetro domains (including quorum association), HyperMetro pairs, and
  HyperMetro consistency groups.
- NAS/vStore tranche: vStore pairs, file-system replication pair creation and
  secondary protection, and file-system HyperMetro domains.
- Typed output classes, table format views, manifest exports, and 62 focused
  unit tests across five DR test files.
- Opt-in integration workflows with `NotConfigured`/`SkippedUnsafe` gating and
  ID-based cleanup.
- Fixed class-literal `[OutputType([...])]` attributes (string form now) so DR
  cmdlets work from a normal `Import-Module` session; verified read-only
  against a lab array. The same fix was applied module-wide (QoS, quota, and
  HyperCDP schedule cmdlets had the identical defect).

## High Priority

> Deduplication note: all High and Medium Priority items below are scoped for
> implementation in
> `todo/alpha-v1.0.0-post-merge-phase-07-replication-hypermetro-completion.md`,
> which re-verified each as still open against current code (2026-07-07;
> confirmed via grep that none of the listed DR getters are registered in
> `Tests/Integration/Private/ReadValidation.ps1`). Status: `open` for all
> bullets in this section.

- Add the DR getters (`Get-DMRemoteDevice`, `Get-DMReplicationPair`,
  `Get-DMReplicationConsistencyGroup`, `Get-DMHyperMetroDomain`,
  `Get-DMHyperMetroPair`, `Get-DMHyperMetroConsistencyGroup`,
  `Get-DMVStorePair`, `Get-DMFileHyperMetroDomain`, and a guarded
  `Get-DMRemoteLun`) to the standing read-only validation in
  `Tests/Integration/Private/ReadValidation.ps1` so every live run exercises
  them.
- Run the gated Replication and HyperMetro mutation workflows against a
  configured remote-array lab pair and record the results (no lab remote
  configuration was available for the initial branch validation).

## Medium Priority

- Systematic `-WhatIf` unit coverage: today only `New-DMReplicationPair` has
  an explicit no-API-call-under-WhatIf test; extend the pattern (or a shared
  `-ForEach` assertion) across the other 51 DR mutators.
- Batch operations: expose `REPLICATIONPAIR/*/batch`,
  `HyperMetroPair/*/batch`, and `ADD_MIRROR/DEL_MIRROR/batch` as array
  parameters on the existing lifecycle cmdlets.
- Quorum server inventory cmdlet so `-QuorumServerId` for
  `Add-DMQuorumServerToHyperMetroDomain` can be resolved without
  DeviceManager.
- Richer enum/status translation on the DR classes where raw codes are still
  surfaced (verify each against the 6.1.6 enum tables).

## Low Priority / Polish

- Dedicated wrappers for `REPLICATIONPAIR/transfer` and
  `modifyPreferredPolicy` endpoints instead of `-ApiProperties` passthrough.
- `Set-DMVStorePair` and a file-system-filtered replication pair getter.
- Server-side `filter=` support on DR getters where the REST API documents it
  (name filtering is currently client-side).
- Pipeline-input unit assertions for the `-Id`-by-property-name lifecycle
  cmdlets.

## Testing and Validation

- Extend the HyperMetro workflow with optional force-start coverage on a
  test-owned pair behind its own opt-in flag (currently not exercised at
  all).
- Add gated workflows for the NAS/vStore tranche (vStore pair lifecycle,
  file-system replication pair lifecycle) once a dual-array NAS lab exists.
- Failover/switchover integration coverage in a dedicated DR exercise window
  (`Replication.AllowFailover`, `HyperMetro.AllowPrioritySwitch`).

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
