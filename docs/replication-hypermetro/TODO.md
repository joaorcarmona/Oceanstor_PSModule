# Replication and HyperMetro TODO

## Current Focus

- Stabilize the shipped DR surface (62 cmdlets after `Get-DMQuorumServer`):
  documentation, live read-only coverage, and the opt-in lab mutation
  workflows.

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
  - **Status (2026-07-09, run ID 20260709033729): Attempted — Blocked on lab
    resources; no DR object was created or mutated.**
    - Replication: the configured remote LUN (`HyperReplica_Lun01`, remote
      device `HWPTLABSTG004`) resolved correctly, but `New-DMReplicationPair`
      failed with `1073749234` — a read-only check confirmed **every**
      `HyperReplica_Lun00..09` remote LUN is already the secondary of a
      pre-existing replication pair, so no free test-usable remote LUN exists.
      All downstream pair/consistency-group steps correctly reported `Blocked`.
      (A first attempt also surfaced that the workflow's hardcoded
      `-InitialSyncType WrittenData` is rejected for non-snapshot volumes on
      this build — error `1073749222`; the workflow now uses `AllData`.)
    - HyperMetro: the configured remote LUN name `HyperMetro_Lun01` does not
      exist on `HWPTLABSTG004` (verified read-only via `Get-DMRemoteLun`), so
      `Verify:Get-DMRemoteLun:HyperMetro` failed and every pair step reported
      `Blocked`. Nothing was created.
    - Remaining blocker: an operator must create/designate a **free**,
      test-dedicated remote LUN for each surface (and a HyperMetro domain
      check) before a re-run. `HyperMetro.AllowDrMutation`,
      `AllowPrioritySwitch`, and `AllowForceStart` were restored to `$false`
      in the committed config per the safe-default guard tests; re-enable them
      only for that supervised session.

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

- Server-side `filter=` on DR getters where the REST API documents it —
  retained client-side (documented fallback) for `Get-DMReplicationPair` and
  `Get-DMHyperMetroPair`: `-Name` matches three fields (local name, remote
  name, id); no single documented server-side filter field covers all three,
  so a single-field server filter would drop valid matches. `Get-DMQuorumServer`
  documents only `range`, no `filter`.

## Testing and Validation

- **Deferred — requires human-supervised run.** HyperMetro force-start
  coverage on a test-owned pair sits behind the default-off
  `HyperMetro.AllowForceStart` gate (workflow step is `SkippedUnsafe` when off;
  command behavior is unit-tested). The gate is independent of
  failover/switchover gates and is never enabled in committed config — a live
  force-start run stays deferred to a supervised session.
- **Deferred — requires dual-array NAS lab.** Gated workflows for the
  NAS/vStore tranche (vStore pair lifecycle, file-system replication pair
  lifecycle).
- **Deferred — requires dedicated per-operation flag + human-supervised run.**
  Failover/switchover integration coverage in a dedicated DR exercise window
  (`Replication.AllowFailover`, `HyperMetro.AllowPrioritySwitch`). These stay
  `SkippedUnsafe` by default and are never run against pre-existing objects.

## Documentation

- **Pending live evidence from Phase 03 / Phase 06 supervised runs.** Refresh
  topic-page examples with real captured output once the lab mutation workflows
  have run end to end. Status: no supervised DR mutation run has executed
  (Phase 03 deferred, 2026-07-07 — see High Priority above), so no sanitizable
  captured output exists yet. Do not fabricate output; leave examples as
  illustrative until a run produces evidence, then sanitize (strip lab IPs,
  serials, WWNs/IQNs, tokens, and identifying IDs) before committing.
- **Pending live switchover validation (Phase 06).** Add a worked "planned
  failover runbook" example (split → switch → resync) only after a supervised
  switchover run exists. Failover/switchover stays `SkippedUnsafe` by default
  (`Replication.AllowFailover` / `HyperMetro.AllowPrioritySwitch`), so this
  runbook must not imply validation occurred until that run is recorded.

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
