# alpha-v1.0.0 — Consolidated Remaining-Work Plan (3 Phases by Priority)

**Generated:** 2026-07-17
**Branch:** `alpha2-v1.0.0`
**Supersedes:** the `alpha-v1.0.0-remaining-open-todos*` phase family (index + phase-01/02/04/05/06/07)
and `followup-name-loopvar-collision-audit.md`, all of which were folded into this file and deleted.
**Still authoritative alongside this file:**
- `todo/release-readiness-go-no-go.md` — the release decision record (current hard-gate: **GO**).
- `docs/*/TODO.md` — the living per-domain backlogs. This plan is the priority roadmap over them;
  those files remain the source of truth for domain detail and are updated as each item closes.

## How to use this plan

- Work top-down: **Phase 1 (High)** → **Phase 2 (Medium)** → **Phase 3 (Low)**.
- Each phase ends with a **Clearing on completion** checklist: when an item is done, strike it here
  and trim the matching entry from the named `docs/*/TODO.md` (and this file). This keeps a single,
  shrinking record instead of parallel stale copies.
- Safety rules are unchanged: one mutation gate per human-supervised live session; test-owned objects
  with captured-ID cleanup only; never mutate a pre-existing object; never guess REST bodies for
  undocumented endpoints.

## Release status snapshot

- **Hard gate: GO.** `./Tests/Invoke-UnitTests.ps1 -FailOnAnalyzerIssue` → 0 Error-severity analyzer
  findings, all unit tests passing (per `release-readiness-go-no-go.md`).
- **No release blockers identified.** Every item below is non-gating: signing/publishing are
  feature-flagged off, and the open mutator defects are on update/test paths whose create/remove
  siblings are already live-validated.

---

## Phase 1 — HIGH priority

Open, actionable code defects with a known next step, plus keeping the release status honest. These
are the only genuine bugs left in shipped cmdlets.

### 1.1 `Set-DMSnmpTrapServer` update — `1077949001` timeout (NeedsInvestigation)
- The original `50331651` rejection is **fixed** (`Set` now always sends `ID`; `Test-DMSnmpTrapServer`
  always sends `CMO_TRAP_SERVER_TYPE`/`CMO_TRAP_VERSION`). `Test-DMSnmpTrapServer` now **Passes** live.
- `Set-DMSnmpTrapServer` no longer returns `50331651` but now fails with
  `OceanStor API error 1077949001: The message has timed out` (PUT ~50 s; read-back shows port
  unchanged).
- **Next step:** make `Set-DMSnmpTrapServer` do a read-modify-write that re-supplies the full mandatory
  field set (`CMO_TRAP_SERVER_IP`/`CMO_TRAP_SERVER_PORT`) rather than a partial `ID` + `PORT` body;
  add/adjust the mock unit test; then a single-gate supervised live re-confirm.
- Files: `POSH-Oceanstor/Public/Set-DMSnmpTrapServer.ps1`,
  `Tests/Unit/Public/Set-DMSnmpTrapServer.Tests.ps1`; evidence in `docs/system-management/TODO.md` #4.

### 1.2 Network field-mapping / update defects (NeedsInvestigation)
- `Get-DMvLan` `Tag` field mapping returns unexpected value (NeedsInvestigation) and the related new
  class field-mapping findings in the same family — `docs/network/TODO.md` "Deferred (with reason)".
- VLAN raw-PUT update experiments return `50331651` ("The entered parameter is incorrect") whether
  `NAME` is omitted or set to a new value — the update body contract is not yet pinned down.
- **Next step:** static-analyze the VLAN update/read body against the 6.1.6 REST reference (mirror how
  1.1 was root-caused); fix the class field map and/or update body; unit test; defer any live run to
  Phase 2's VLAN session.
- Files: `POSH-Oceanstor/Public/*vLan*.ps1`, `class-OceanStorvLan.ps1`; evidence in
  `docs/network/TODO.md`.

### Clearing on completion (Phase 1)
- [ ] 1.1 fixed + live-confirmed → clear `docs/system-management/TODO.md` High Priority #4; strike here.
- [ ] 1.2 fixed → clear the matching `docs/network/TODO.md` "Deferred (with reason)" / NeedsInvestigation
      rows; strike here.
- [ ] If any Phase 1 defect ever becomes gating (none are today), update
      `release-readiness-go-no-go.md`.

---

## Phase 2 — MEDIUM priority

Release-readiness ops, the remaining scheduled human-supervised live sessions, and documentation
reconciliation. None block the alpha gate.

### 2.1 CI signing & publishing readiness (maintainer/ops decision)
- Both gates default off: `.github/workflows/release.yml` checks `vars.SIGNING_ENABLED` (else re-uploads
  unsigned) and `vars.PUBLISH_ENABLED` (else dry-run against a disposable local `PSRepository`).
- Actions (maintainer only, never as automated work):
  1. Source/approve a code-signing certificate through the org process; store the secret reference in
     repo/environment secrets (never in-repo).
  2. Flip `vars.SIGNING_ENABLED = true`; run the release workflow against a test tag; confirm the signed
     artifact validates.
  3. Flip `vars.PUBLISH_ENABLED = true` for one deliberate dry run against a disposable feed before any
     unattended release. **A real Gallery publish is irreversible** (versions can't be reused).
- Files: `.github/workflows/release.yml`.

### 2.2 Scheduled human-supervised live-validation sessions (one gate per session)
Already **Passed/Resolved** (do not re-run; listed only so they aren't rescheduled): SNMP USM user,
failover-group workflow, syslog server (resolved 2026-07-17), local role + local user lifecycle
(resolved 2026-07-17).

Remaining sessions, easiest-unblocked first:
1. **Network — VLAN live workflow.** Needs a human-reviewed lab dry run of `Get-DMVlanParentPortStatus`
   (idle-port guard) against real hardware first, then the gated create/delete. Pairs with the 1.2 fix.
   Currently `SkippedUnsafe` by design (guard confirmed no harness-owned idle port exists).
2. **Replication/HyperMetro — lab-pair mutation workflow.** Blocked on lab resources: every
   `HyperReplica_Lun0x` remote LUN is already a secondary of a pre-existing pair and `HyperMetro_Lun01`
   is absent on the remote device. Needs operator-supplied `RemoteDeviceId`/`RemoteLunId`/`DomainId`
   and a config review. HyperMetro `AllowDrMutation`/`AllowPrioritySwitch`/`AllowForceStart` must stay
   `$false` in committed config.
3. **Replication/HyperMetro — dual-array NAS lab workflow.** Needs a second array in the lab topology
   (highest setup cost).
4. **Replication/HyperMetro — failover/switchover exercise window.** Highest blast radius; own dedicated
   window, never combined with another gate; blocked behind item 2's resources.
- Config gates live in `IntegrityValidationConfig.psd1` (all default off). Record every outcome in the
  owning `docs/*/TODO.md` with `Status (date): ...`.

### 2.3 Documentation polish reconciliation
- Fix the stale `alpha-v1.0.0-post-merge-phase-06-...` cross-reference inside `docs/network/TODO.md`'s
  "Future Feature Branches" header (that naming scheme no longer exists — point at the current file or
  drop the filename).
- Re-verify each domain's "Low Priority / Polish" section against actual doc content after commit
  `c79921a` (Phase 08 polish); strike items already done rather than redoing them.
- Add the QoS SmartQoS glossary + compact policy-inventory reporting examples if still missing.
- Replication/HyperMetro "Documentation" live-evidence refresh **depends on 2.2** running.
- Guardrails: no lab IP `10.10.10.24` in public docs (use `$storageIP = 'StorageIP'`); keep raw
  validation/gap-analysis files out of `docs/` (they belong in `todo/` or `*archived-commands/`).

### Clearing on completion (Phase 2)
- [ ] 2.1 done → remove the CI signing/publishing follow-up from `Oceanstor_PSModule_TODO.md`; strike here.
- [ ] Each 2.2 session run → record outcome in the owning `docs/*/TODO.md`; strike the session here.
- [ ] 2.3 done → trim the reconciled "Low Priority / Polish" rows and the stale network cross-ref; strike here.

---

## Phase 3 — LOW priority

Deferred-indefinitely decisions (no action until an external unblocker changes) and the future-feature
backlog for the next planning cycle. Nothing here is scheduled work.

### 3.1 Safety-critical deferred indefinitely
Do **not** implement until the stated blocker is externally resolved. Re-open trigger in parentheses.

| Item | Blocker (re-open when…) |
|---|---|
| `Import-DMCertificate` | No documented upload endpoint (Huawei publishes/confirms one) |
| `Export-DMCertificate` | Unquantified private-key retrieval risk (path semantics + risk confirmed) |
| `Remove-DMCertificate` | Endpoint documented but no approved lab-safe procedure (reviewed procedure exists) |
| Storage-pool Set/create/delete/resize | No per-generation (V3 vs V6) lab confirmation (V3 lab or vendor confirmation) |
| Bond member add/remove | No documented REST endpoint (confirmed reference section) |
| DR batch operations | No documented REST endpoint (confirmed reference section) |
| Alarm acknowledge | No endpoint documented — effectively rejected (Huawei documents one) |
| Alarm clear — **live validation** | `Clear-DMAlarm` already ships (`ConfirmImpact=High`, clear-by-sequence); a safe test-alarm generator exists |
| LDAP/AD / Email-SMTP / password-policy | Research-only; no dedicated endpoint for password policy (graduated to a feature branch, see 3.2) |

- Never speculatively guess REST bodies for the undocumented endpoints above.
- Research note already captured: `docs/system-management/ldap-ad-smtp-alerting-research.md`.

### 3.2 Future feature branches backlog (next feature cycle)
- **Network:** static routes/gateways (query/create/delete); iSCSI portal/CHAP cmdlets; NVMe-oF
  interface cmdlets; per-port performance/statistics getters; LLDP neighbor getter; friendly-name enum
  aliases (`-BondPortType HostService`, etc.) with numeric back-compat.
- **Replication/HyperMetro:** remote LUN rescan (`remote_lun/scan_remote_lun`) + remote device link
  management; DR dashboards/reporting (pair-health rollups via the report template system).
- **QoS:** `qos-filesystem-live-validation` (Medium); `qos-admin-cookbook` (Medium).
- **Block storage:** block-storage-troubleshooting; protection-group-live-examples.
- **File/NAS:** nas-service-config; quota-live-matrix; nas-troubleshooting-docs.
- **Snapshots:** snapshot-policy-research; snapshot-restore-runbooks; snapshot-copy-cookbook.
- **System management:** LDAP/AD auth implementation; Email/SMTP alerting implementation; alarm/event
  lifecycle enhancements beyond the read-only `Get-DMAlarmHistory`.

### Clearing on completion (Phase 3)
- [ ] When a 3.1 blocker is externally resolved → move that item into a dedicated implementation phase
      (out of this file), then strike it here.
- [ ] When a 3.2 item is picked up → create its own scoped phase/branch, then strike it here.

---

## Appendix — Completed / resolved (recorded so history isn't lost)

- `$name` loop-variable collision audit — **COMPLETE (2026-07-09)**, all 9 `Get-DM*Performance.ps1`
  files renamed to `$metricName`; 57/0 targeted Pester green.
- Release-readiness refresh — **DONE (2026-07-09)**: go/no-go headline corrected to **GO** (original
  NO-GO evidence retained as history); dangling `post-merge-phase-*` refs repointed in
  `Oceanstor_PSModule_TODO.md`.
- SNMP trap `50331651` — root cause + code/unit-test fix landed 2026-07-09; `Test-DMSnmpTrapServer`
  live-**Passed** (the `Set` timeout `1077949001` is the residual, now Phase 1.1).
- Syslog `50331651` — **RESOLVED, live-confirmed 2026-07-17** (`CMO_ALARM_SYSLOG_SERVER_IP` field-name fix).
- Role/local-user `50331651` — **RESOLVED, live-confirmed 2026-07-17** (`New-DMRole -PermitList` /
  `roleSource` drop; `New-DMLocalUser` `SCOPE`/`ROLEID` fix).
- SNMP USM user + failover-group workflows — **Passed** live 2026-07-09.
- `Get-DMAlarmHistory` implemented (2026-07-08); Docs Phase 08 polish (commit `c79921a`); SNMP USM
  analyzer finding suppressed with justification (Phase 01).
