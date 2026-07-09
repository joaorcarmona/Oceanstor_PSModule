# alpha-v1.0.0 Remaining Open TODOs Phase 04 — Live-Validation Session Scheduling

**Type:** Decision-only / live-validation planning. **No live validation is performed by this
phase or by writing this file.**
**Live validation allowed in this phase:** No — this document only schedules and describes future
supervised sessions; it does not execute them.
**Release-blocking:** No — all items here are already safely deferred behind default-off config
gates; the alpha release does not depend on them running.

## Purpose

Consolidate every still-deferred, human-supervised live-validation session across domains into a
single scheduling document, so future sessions have one place to check before consuming their
"one gate per supervised session" budget.

## Source TODOs / evidence

- `docs/network/TODO.md` — failover-group workflow deferred ("Status (Phase 03, 2026-07-07):
  Deferred — not run this session... needs its own dedicated supervised session"); VLAN live
  workflow deferred pending a human-reviewed lab dry run of the already-implemented idle-port guard
  (`Get-DMVlanParentPortStatus`).
- `docs/replication-hypermetro/TODO.md` — lab-pair mutation workflow deferred ("Status (Phase 03,
  2026-07-07): Deferred — not run... operator must supply the lab-pair IDs and review the config
  before a dedicated single-gate supervised run"); dual-array NAS lab workflow deferred; dedicated
  failover/switchover DR exercise window deferred (`Replication.AllowFailover`,
  `HyperMetro.AllowPrioritySwitch`).
- `docs/system-management/TODO.md` — remaining single-gate live runs still separately scheduled/
  deferred: `AllowSnmpUsmUser`, `AllowSyslogServer`, `AllowLocalUserLifecycle`.
- `todo/alpha-v1.0.0-remaining-open-todos-phase-01-release-readiness-refresh.md` (this plan
  family) — the `Set-DMSnmpTrapServer`/`Test-DMSnmpTrapServer` defect fix will also need a
  supervised live re-check once a code fix is implemented.

## Current repository evidence

- All named config gates (`Network.AllowFailoverGroupLifecycle`, `Network.AllowVlanLifecycle`,
  `Replication.*`, `HyperMetro.AllowForceStart`, `HyperMetro.AllowPrioritySwitch`,
  `Replication.AllowFailover`, `SystemManagement.AllowSnmpUsmUser`,
  `SystemManagement.AllowSyslogServer`, `SystemManagement.AllowLocalUserLifecycle`) exist in
  `IntegrityValidationConfig.psd1` and default off, per the domain TODO files and
  `Reports/getter-integrity-last-result.md` (2026-07-08 run: all corresponding rows are
  `SkippedUnsafe`, by design).
- The 2026-07-07 supervised session's single mutation gate was spent on the SystemManagement
  SNMP-trap surface (per both the Network and Replication-HyperMetro TODO files) — establishing the
  "one gate per supervised session" discipline this document schedules against.

## Classification

Decision-only / scheduling. Not release-blocking. No code changes.

## Scope

- Enumerate every deferred live session in one place with its blocker and prerequisite.
- Propose a recommended order for future single-gate sessions based on risk and unblocking value.
- Explicitly restate the one-gate-per-session discipline so future contributors do not try to
  enable multiple mutation gates in the same supervised run.

## Out of scope

- Actually running any of the sessions listed below.
- Enabling any config gate in committed configuration.
- Connecting to any array (lab or production) as part of this planning task.

## Implementation tasks (for future supervised sessions, not this task)

Recommended order, by blocker difficulty (easiest-unblocked first):

1. **SystemManagement — `AllowSyslogServer`**: no external prerequisite beyond a lab syslog
   target; lowest-friction next session.
2. **SystemManagement — `AllowSnmpUsmUser`**: needs a lab USM credential set prepared in advance;
   moderate friction.
3. **SystemManagement — `AllowLocalUserLifecycle`**: needs care to avoid locking out the operator's
   own session; schedule with a known-good fallback credential available.
4. **SystemManagement — SNMP trap-server re-check** (from Phase 01 of this plan): only after the
   `50331651` code fix lands; single-purpose session to confirm the fix.
5. **Network — failover-group workflow**: operator scheduling only, workflow/gate already verified
   in place.
6. **Network — VLAN live workflow**: needs a human-reviewed lab dry run of
   `Get-DMVlanParentPortStatus` against real hardware first, then the gated create/delete run.
7. **Replication/HyperMetro — lab-pair mutation workflow**: needs operator-supplied
   `RemoteDeviceId`/`RemoteLunId`/`DomainId` and a config review before scheduling.
8. **Replication/HyperMetro — dual-array NAS lab workflow**: needs a second array in the lab
   topology; highest setup cost.
9. **Replication/HyperMetro — dedicated failover/switchover exercise window**: highest blast
   radius; schedule last, in its own dedicated window, never combined with another gate.

Each session must: enable exactly one gate, use a test-owned object with captured-ID cleanup, and
record the outcome in the relevant domain `TODO.md` afterward (status + date, per the existing
"Status (Phase NN, date): ..." convention already used in these files).

### Update (2026-07-09 live sweep, run ID 20260709033729)

A supervised sweep with the gates enabled in config executed items 1–5 and 7; the harness
sequenced one workflow surface at a time. Outcomes (details in each domain `TODO.md`):

1. `AllowSyslogServer` — **Failed / NeedsInvestigation** (`syslog_addip` rejects IP-only body,
   `50331651`; nothing created).
2. `AllowSnmpUsmUser` — **Passed** end-to-end, cleanup by captured ID.
3. `AllowLocalUserLifecycle` — **Blocked** by `New-DMRole` `50331651` (role likely requires a
   `permitList`); user steps safely skipped.
4. SNMP trap-server re-check — **partially resolved**: `Test-DMSnmpTrapServer` now Passed;
   `Set-DMSnmpTrapServer` fails with a new `1077949001` timeout (NeedsInvestigation).
5. Failover-group workflow — **Passed** end-to-end (after fixing a `Get-DMFailoverGroup -Name`
   null-response bug found live).
6. VLAN live workflow — **not run**, still `SkippedUnsafe`: the idle-port guard positively
   confirmed no harness-owned idle port exists; remains deferred by design.
7. Replication/HyperMetro lab-pair workflow — **Blocked on lab resources**: every
   `HyperReplica_Lun0x` remote LUN is already a secondary of a pre-existing pair, and
   `HyperMetro_Lun01` does not exist on the remote device. No DR object created or mutated.
   HyperMetro `AllowDrMutation`/`AllowPrioritySwitch`/`AllowForceStart` restored to `$false` in
   committed config per the safe-default guard tests.
8. Dual-array NAS lab workflow — unchanged, deferred (lab topology).
9. Failover/switchover exercise window — unchanged, deferred (blocked by item 7's resources).

## Files likely to inspect

- `docs/network/TODO.md`, `docs/replication-hypermetro/TODO.md`, `docs/system-management/TODO.md`
- `IntegrityValidationConfig.psd1`
- `Tests/Integration/Private/Workflows/FailoverGroup.ps1`
- `Tests/Integration/Private/Workflows/SystemManagement.ps1`
- `docs/*/safety-and-live-validation.md`

## Files likely to modify

- None in this planning task. Future sessions will update the relevant domain `TODO.md` files with
  outcomes.

## Safety considerations

- Strict one-gate-per-supervised-session discipline, per existing project convention.
- Every session must use test-owned objects only, captured-ID cleanup, and the sanitized credential
  pattern:
  ```powershell
  $storageIP = '10.10.10.24'
  $cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
  # add -SkipCertificateCheck if required by the lab
  ```
- Never print or log credential contents.
- Never mutate any object not created during the same validation run.

## Testing strategy

- N/A for this planning phase — the "testing" is the future supervised sessions themselves,
  scheduled here but not executed.

## Verification commands

```powershell
git diff --check
git status --short
Select-String -Path IntegrityValidationConfig.psd1 -Pattern 'AllowFailoverGroupLifecycle|AllowVlanLifecycle|AllowSnmpUsmUser|AllowSyslogServer|AllowLocalUserLifecycle|AllowFailover|AllowPrioritySwitch'
```

## Dependencies

- Depends on Phase 01's SNMP defect fix landing before item 4 in the recommended order can run.
- Otherwise independent of other phases in this plan.

## Completion criteria

- This scheduling document is complete once committed. It is superseded/updated (not "completed")
  as each individual session actually runs and its outcome is recorded in the domain TODO files.

## Risks / notes

- No new risk — this phase only organizes already-deferred, already-gated work.
