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

**Status 2026-07-17: Phase 1 is code-complete.** Both remaining shipped-cmdlet defects had their
code + unit-test fixes landed on 2026-07-17 (commit `aa3c9b3`). The only work left for either is a
supervised live re-confirm, which is a Phase 2.2 live-session activity — not open code work. Full
detail is preserved in the Appendix; the live re-confirms are tracked under Phase 2.2.

### 1.1 `Set-DMSnmpTrapServer` update — DONE (code) ✅
- ~~`1077949001` timeout on partial-field `PUT`~~ — **fixed 2026-07-17**: `Set-DMSnmpTrapServer` now
  does a read-modify-write via `Get-DMSnmpTrapServer -Id`, re-supplying the full mandatory set
  (`ID` + `CMO_TRAP_SERVER_IP` + `CMO_TRAP_SERVER_PORT`, plus USM/type/version) and overlaying only
  caller-passed fields. Mock unit tests guard the regression. (The earlier `50331651` was already
  fixed 2026-07-09; `Test-DMSnmpTrapServer` passed live then.)
- **Remaining:** one supervised live re-confirm on reachable lab hardware → Phase 2.2 SNMP gate.

### 1.2 Network VLAN modify body — DONE (code) ✅
- ~~`Set-DMvLan` `50331651` (MTU update)~~ — **fixed 2026-07-17**: body now echoes `ID` alongside
  `MTU` (§4.6.9.3.8 marks both Mandatory); unit test `Tests/Unit/Public/Set-DMvLan.Tests.ps1` added.
  The earlier `NAME`-omit/set experiments were a red herring — the modify interface documents no
  `NAME` field.
- `Get-DMvLan` empty `Tag` — static analysis 2026-07-17 concluded the `OceanStorvLan` class map is
  correct against the 6.1.6 reference (constructing from the doc's own example JSON yields
  `Tag = 123`). The empty live value is a firmware/response discrepancy, **not statically fixable**
  and unsafe to guess an alternate field for. Moved to Phase 2.2 VLAN session (capture raw
  `GET vlan` JSON, diff vs schema, only then decide on a tolerant fallback).

### Clearing on completion (Phase 1)
- [x] 1.1 code fixed (2026-07-17, `aa3c9b3`) → live re-confirm now tracked under Phase 2.2 SNMP gate.
- [x] 1.2 `Set-DMvLan` fixed (2026-07-17, `aa3c9b3`); `Get-DMvLan Tag` moved to Phase 2.2 VLAN session.
      `docs/network/TODO.md` rows already carry the dated resolution.
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
1. ~~**SNMP — `Set-DMSnmpTrapServer` update re-confirm (Phase 1.1).**~~ **DONE 2026-07-20** —
   re-confirmed live on `10.10.10.24` via a reversible port round-trip on a pre-existing reachable
   trap server (Id `0`, `10.10.12.84`): update applied and reverted with no `1077949001`/`50331651`,
   mandatory-field re-supply left other fields intact. Rules out the last `NeedsInvestigation`
   candidate (unreachable TEST-NET-1 target). Outcome recorded in `docs/system-management/TODO.md` §4.
2. ~~**Network — VLAN live workflow (Phase 1.2).**~~ **DONE 2026-07-20** (commit `85ecad0`;
   re-verified read-only 2026-07-20). Operator-supervised create/delete round-trip re-confirmed the
   `Set-DMvLan` MTU fix (`-Mtu 1400` accepted with `error.code 0`, `1600` correctly rejected with
   `1073813506`), and the raw `GET vlan`/`GET vlan/{id}` capture settled the empty-`Tag` discrepancy —
   `TAG` comes back **populated** (`Get-DMvLan` read-back shows `Vlan Tag Id='50'` for both live VLANs;
   a fresh VLAN read `TAG='130'`), so the 2026-07-09 empty value was a transient firmware/response
   discrepancy, not a mapping bug — no code change warranted. Full record in `docs/network/TODO.md`.
   **Residual (by-design, not a Phase 2 gate):** on this lab the `System-defined` failover group holds
   all ports, so `Get-DMVlanParentPortStatus` can never green-light an idle port — the unattended
   harness stays `SkippedUnsafe` and live VLAN runs remain operator-designated-port sessions. Optional
   future enhancement (teach the guard to ignore `System-defined` + accept operator ports via config) is
   tracked in `docs/network/TODO.md`, not here.
3. **Replication/HyperMetro — lab-pair mutation workflow.** Blocked on lab resources: every
   `HyperReplica_Lun0x` remote LUN is already a secondary of a pre-existing pair and `HyperMetro_Lun01`
   is absent on the remote device. Needs operator-supplied `RemoteDeviceId`/`RemoteLunId`/`DomainId`
   and a config review. HyperMetro `AllowDrMutation`/`AllowPrioritySwitch`/`AllowForceStart` must stay
   `$false` in committed config.
4. **Replication/HyperMetro — dual-array NAS lab workflow.** Needs a second array in the lab topology
   (highest setup cost).
5. **Replication/HyperMetro — failover/switchover exercise window.** Highest blast radius; own dedicated
   window, never combined with another gate; blocked behind item 3's resources.
- Config gates live in `IntegrityValidationConfig.psd1` (all default off). Record every outcome in the
  owning `docs/*/TODO.md` with `Status (date): ...`.

### 2.3 Documentation polish reconciliation
- ~~Fix the stale `alpha-v1.0.0-post-merge-phase-06-...` cross-reference inside `docs/network/TODO.md`'s
  "Future Feature Branches" header.~~ **DONE** — that header now reads "Tracked in the current
  open-issues / remaining-open-todos planning set" with no stale filename.
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
  live-**Passed**. `Set` timeout `1077949001` — read-modify-write code + unit-test fix landed
  2026-07-17 (`aa3c9b3`); only a supervised live re-confirm remains (Phase 2.2 SNMP session).
- `Set-DMvLan` `50331651` (MTU update) — modify-body fix (echo `ID` alongside `MTU`, §4.6.9.3.8) +
  unit test `Set-DMvLan.Tests.ps1` landed 2026-07-17 (`aa3c9b3`); live re-confirm Phase 2.2 VLAN
  session. `Get-DMvLan` empty `Tag` static-analyzed 2026-07-17 → firmware/response discrepancy,
  raw-JSON capture folded into the same VLAN session.
- Syslog `50331651` — **RESOLVED, live-confirmed 2026-07-17** (`CMO_ALARM_SYSLOG_SERVER_IP` field-name fix).
- Role/local-user `50331651` — **RESOLVED, live-confirmed 2026-07-17** (`New-DMRole -PermitList` /
  `roleSource` drop; `New-DMLocalUser` `SCOPE`/`ROLEID` fix).
- SNMP USM user + failover-group workflows — **Passed** live 2026-07-09.
- `Get-DMAlarmHistory` implemented (2026-07-08); Docs Phase 08 polish (commit `c79921a`); SNMP USM
  analyzer finding suppressed with justification (Phase 01).
