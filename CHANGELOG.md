# Changelog

All notable development work, design decisions, and live-validation evidence for
`POSH-Oceanstor` (the Oceanstor PowerShell module). The format is loosely based on
[Keep a Changelog](https://keepachangelog.com/); this project uses a milestone-based
prerelease scheme.

> ## Status: `v1.0.0-alpha1` scope — **COMPLETE** ✅
>
> As of **2026-07-20**, every planned item for the `alpha-v1.0.0` milestone is done and
> validated. The release hard-gate is **GO**: `./Tests/Invoke-UnitTests.ps1
> -FailOnAnalyzerIssue` reports **0 Error-severity analyzer findings and 1232/1232 tests
> passing**. All shipped mutators that can be validated against the single available lab
> array have been live-confirmed.
>
> **What "complete" means here:** the alpha-v1.0.0 command surface, correctness fixes, CI,
> and documentation are finished. The items under **[Deferred by design](#deferred-by-design)**
> and **[Future feature branches](#future-feature-branches)** are *intentionally out of
> scope* — each is blocked on an external prerequisite (a second lab array, an undocumented
> REST endpoint, or a maintainer/ops decision), not on unfinished work. They are recorded
> here so nothing is lost, not because they are owed for this release.
>
> **History note:** this file consolidates the former scattered trackers
> (`Oceanstor_PSModule_TODO.md`, `todo/*.md`, and the seven `docs/*/TODO.md`). Their verbatim
> per-item text and full rationale remain recoverable in git history (`git log --follow`).

---

## Release readiness — `v1.0.0-alpha1`

**Hard gate: GO** (Phase 01, 2026-07-07; re-affirmed through 2026-07-20).

- **Manifest / exports:** `ModuleVersion = 1.0.0`, `Prerelease = alpha1`; `Test-ModuleManifest`
  OK; public-command count matches `Public/*.ps1` (no export drift).
- **Unit + analyzer gate:** 1232/1232 tests pass; 0 Error-severity analyzer findings. The two
  historical `PSAvoidUsingUsernameAndPasswordParams` errors on the SNMPv3 USM cmdlets were
  cleared with a justified, reviewed `[SuppressMessageAttribute]` (USM has no `PSCredential`
  equivalent — the username/secret pair is the protocol contract). Remaining Warning/Information
  findings are non-blocking.
- **Read-only live validation:** getter-integrity run `Passed=54, Blocked=0, Failed=0`.
- **Doc safety sweep:** no lab IPs or gap-analysis reports in published docs.
- **Package hygiene:** the release workflow stages only `POSH-Oceanstor/*` (never `todo/`,
  `Tests/`, `Reports/`, `.github/`).
- **Mutator safety:** all destructive/failover mutators carry `SupportsShouldProcess` +
  `ConfirmImpact = 'High'`; `New-*` creation commands are the accepted lower-blast-radius
  exception.

**Remaining non-gating ops items (do not block the alpha tag):**
- Source/approve a code-signing certificate, then flip CI `SIGNING_ENABLED`; do a first
  supervised `PUBLISH_ENABLED` dry-run. Both default **off** — no real Gallery publish has
  been attempted.
- When tagging, use `v1.0.0` (not `v1.0.0-alpha1`) — the release workflow's
  tag-vs-`ModuleVersion` guard compares against the bare `1.0.0`; the prerelease is carried
  by the manifest's `Prerelease` field.

---

## [1.0.0-alpha1] — Completed & validated

### Architecture — native pipeline & per-item session

- **Multi-object pipeline input fixed.** All 46 `Set-`/`Remove-`/`Rename-`/`Add-` commands wrap
  their body in `begin`/`process`/`end` so every piped object is processed (previously only the
  last bound item ran). `WebSession` lost its by-value `ValueFromPipeline` binding (the actual
  cause of the silent single-item bug); each identifying parameter now binds
  `ValueFromPipelineByPropertyName` with an `[Alias]` matching the real class property.
- **Per-item session resolution:** explicit `-WebSession` > the piped object's own session >
  `$script:CurrentOceanstorSession` — supports both "connect and forget" and concurrent
  multi-array use.
- **Continue-on-error:** a failing item reports via `WriteError` and does not abort the batch
  (`Remove-Item -ErrorAction Continue` semantics); `-ErrorAction Stop` still escalates.
- **`ValidateScript` network calls moved into `process{}`** to remove a binding-order hazard;
  three commands using an unsafe `$script:_dm*` caching shortcut were redesigned for safe
  per-item processing.
- Verified with 515 unit tests plus two live mutation runs (0 failures, 0 leftover test-owned
  resources).

### Correctness

- **`filter=` exact-vs-fuzzy bug fixed.** A single colon (`field:value`) is a substring match,
  double colon (`field::value`) is exact. `Get-DMhostbyId` had been returning every host whose
  ID *contained* the value (40 hosts for ID `5`). Fixed across all five known single-colon
  sites: `Get-DMhostbyFilter`, `Get-DMLunbyFilter`, `Get-DMFileSystemSnapshot` (`PARENTID`),
  `Get-DMLunSnapshot` (`SOURCELUNID`), and `Get-DMAlarm` (`alarmStatus`). A client-side `-Like`
  re-check always backstops an imprecise server result.
- **`ArgumentCompleter` private-function bug fixed.** A completer calling an unexported function
  or class literal silently falls back to path completion (invisible to `InModuleScope` tests).
  Audited all completers; fixed the two affected without adding public commands.
- Capacity-expansion read-back checks (`Set-DMLun`/`Set-DMFileSystem -Capacity`); `Set-*`
  read-back verification of description/properties (not just renamed identity); mutation
  ownership-transfer-after-rename cleanup tests.

### Resilient REST integration

- **Pagination audit.** Migrated every Tier-1 list getter (disks, initiators, mapping/groups,
  NAS, hosts, alarms — counts that scale with provisioning, not chassis) onto
  `Invoke-DMPagedRequest`. Tier-2 (chassis-bounded) and Tier-3 (different endpoint shape)
  documented as accepted residual / not-at-risk.
- **Standardized REST error mapping.** New `Assert-DMApiSuccess` helper makes all 68 mutation
  commands throw a structured `ErrorRecord` on non-zero `error.Code` (they previously returned
  the raw error object silently). Session-expired errors now append an actionable hint.
- **Missing-mandatory-body-field fixes (`50331651`/`1077949001`).** OceanStor `PUT` modify
  interfaces reject bodies that omit a Mandatory field (usually `ID`, which must be echoed *in
  the body*, not just the URL path). Fixed `Set-DMSnmpTrapServer` (read-modify-write re-supplying
  `ID`+IP+PORT), `Set-DMvLan` (`ID`+`MTU`), and `Set-DMFailoverGroup` (`ID`). The doc's terse
  example body is not the contract — the Parameters table is.

### Performance

- **N+1 host-fetch eliminated.** 11 commands resolved a single host by calling fetch-all
  `Get-DMhost` (which enriches every host with 2 REST calls each — 400+ round-trips at 213
  hosts). Repointed to server-side `Get-DMhostbyName`. Verified live: `Remove-DMHost` 60,114ms →
  576ms, and similar across the set; 0 errors over 3,673 traced requests.

### CI, cross-platform & maintainability

- GitHub Actions CI (`powershell.yml`) across windows/ubuntu/macOS; PSScriptAnalyzer integrated
  into the unit runner (115 prior findings resolved); Pester 5 idioms with a pinned
  `5.x` version ceiling.
- Release pipeline (`release.yml`) on published Releases: manifest + tag-agreement validation,
  ScriptAnalyzer + full Pester gate, module-only packaging, then signing/publishing **gated off
  by default** (`SIGNING_ENABLED`/`PUBLISH_ENABLED`), third-party actions SHA-pinned, secrets
  never echoed.
- Explicit `FunctionsToExport`; singular noun cardinality (30 getters renamed with
  back-compat aliases); `Delete()` on all mutable classes; CI inventory check fails on any
  public command/class missing from coverage metadata; module-scoped session fallback;
  `SupportsShouldProcess` on all 74 mutators; explicit unit suffixes on size properties
  (`Lun Size (GB)`).
- Reusable sanitized API-mock fixtures (`DMResponseFixtures.ps1`) as a pilot migration.

### Command-coverage decisions

- **Mapping views — accepted (cmdlets only).** Shipped `Set-DMMappingView` +
  `Rename-DMMappingView` (name/description only; associations stay on `Add-/Remove-DM*`). No
  object `Rename()` method (rename is cmdlet-only across the module by convention).
- **Storage pools — Rename accepted & live-validated; Set deferred.** `Rename-DMstoragePool`
  shipped and confirmed via reversible round-trip (see live history). `Set`/create/delete/resize
  deferred — see [Deferred by design](#deferred-by-design).
- **NAS children — already resolved by code.** `Set-DMCifsShare`/`Set-DMdTree`/`Set-DMnfsShare`/
  `Set-DMnfsClient` already provide update; no new cmdlets needed.
- **Network objects — resolved by code.** Full mutation lifecycles for bonds, VLANs, LIFs, and
  failover groups shipped on the merged network branch.

### Rejected (with rationale)

- **Dynamic parameter-to-payload transformer** — the mapping isn't mechanical (key renames,
  value transforms, hardcoded constants, per-field PATCH gating); a generic transformer would
  add indirection without removing the per-field logic. Matches how Az/PowerCLI/vendor SDKs work.
- **Active token lifecycle validation** — silent re-auth would reopen the deliberate "don't
  retain credentials in memory" decision; Huawei's login returns no refresh token or TTL, so an
  expiry check is racy (TOCTOU). A narrower session-expired message was shipped instead.
- **Initiator action methods** — initiators stay command-only. Identity is the immutable
  WWN/IQN/NQN; the real mutations are host associations already covered by explicit
  `ShouldProcess` commands. Object methods would hide the `-Confirm` safety path.

---

## Live-validation history

All live runs used the lab array `10.10.10.24` with `-SkipCertificateCheck`, test-owned or
fully-reversible objects only, and cleanup by captured ID.

| Date | Item | Result |
|---|---|---|
| 2026-07-07 | Read-only getter integrity sweep | `Passed=54, Blocked=0, Failed=0` |
| 2026-07-09 | Network supervised stack (bond → VLAN → LIF → failover group) | Validated; operator-designated link-down ports, LIFO teardown |
| 2026-07-09 | HyperCDP schedule full lifecycle (create/get/set/associate/enable/remove) | Passed (2 harness fixes: dot-source whitelist, 31-char name cap) |
| 2026-07-09 | Storage-pool rename round-trip | Passed (original restored) |
| 2026-07-17 | `Set-DMFailoverGroup` (ID-in-body fix) | Accepted, read-back, removed — no `50331651` |
| 2026-07-20 | Storage-pool rename re-confirm (`StoragePool001`, Id 0) | Both legs applied + read-back; pool restored |
| 2026-07-20 | `Set-DMSnmpTrapServer` update re-confirm (Id 0 port round-trip) | Applied + reverted; no `1077949001`/`50331651`; other fields preserved |
| 2026-07-20 | VLAN `Set-DMvLan` MTU + empty-`Tag` discrepancy | `-Mtu 1400` accepted, `1600` correctly rejected; `TAG` reads populated (transient firmware artifact, not a bug) |
| 2026-07-20 | Doc polish: QoS glossary + policy-inventory (verified present); file-storage & snapshots compact inventory views (authored, every property name live-verified read-only) | Complete |

---

## Deferred by design

**Not owed for `v1.0.0-alpha1`.** Each item is blocked on a stated external prerequisite. Do not
implement until the re-open trigger is met; never guess REST bodies for undocumented endpoints.

### Blocked on hardware / operator input
- **Replication & HyperMetro live mutation** — pair mutation, dual-array NAS, and
  failover/switchover/priority-switch exercises. Need a **second lab array** plus operator-supplied
  `RemoteDeviceId`/`RemoteLunId`/`DomainId`. These stay `SkippedUnsafe` by default and never touch
  pre-existing DR objects.
- **Storage-pool `Set`/create/delete/resize** — persistent, non-reversible pool state; the module
  targets multiple generations (V3 & V6) but the on-branch REST reference covers only Dorado
  6.1.6. Re-open with a per-generation lab array or vendor confirmation; scope any `Set` to
  description/threshold only, never capacity/tier/protection.

### Blocked on undocumented / missing REST endpoints
- **Certificate import / export / remove** — no documented upload endpoint; unquantified
  private-key retrieval risk; no approved lab-safe removal procedure.
- **Bond member add/remove** and **DR batch operations** — no documented REST endpoint.
- **Alarm acknowledge** — the 6.1.6 reference documents no acknowledge/confirm endpoint
  (`confirmTime` is a read-only field only); effectively rejected.
- **Alarm clear — live validation.** `Clear-DMAlarm` ships (`DELETE alarm/currentalarm?sequence=`,
  `ConfirmImpact = 'High'`, clear-by-captured-sequence only). Live validation is blocked because
  **no REST endpoint generates a disposable test alarm** — a full sweep of the 6.1.6 reference
  confirms the only "test" alarm verbs (`alarm_restore/test_alarm_restore_address`,
  `alarm_sms/send_test_sms`) test *notification delivery*, not alarm *creation*. Re-open when a
  feature branch adds a reliable test-alarm generator; never clear pre-existing alarms.

### Research → graduated to feature work
- **LDAP/AD auth, Email/SMTP alerting, password-policy** — authentication/alerting-sensitive;
  research captured in `docs/system-management/ldap-ad-smtp-alerting-research.md`.

---

## Future feature branches

Next-cycle work; each needs its own scoped branch. Not part of this release.

- **Network:** static routes/gateways; iSCSI portal/CHAP; NVMe-oF interface cmdlets; per-port
  performance/stats getters; LLDP neighbor getter; friendly-name enum aliases
  (`-BondPortType HostService`) with numeric back-compat.
- **Replication/HyperMetro:** remote LUN rescan + remote device link management; DR
  dashboards/reporting (pair-health rollups via the report template system).
- **QoS:** `qos-filesystem-live-validation`; `qos-admin-cookbook`.
- **Block storage:** `block-storage-troubleshooting`; `protection-group-live-examples`.
- **File/NAS:** `nas-service-config` (AD/LDAP/CIFS setup); `quota-live-matrix`;
  `nas-troubleshooting-docs`.
- **Snapshots:** `snapshot-policy-research`; `snapshot-restore-runbooks`; `snapshot-copy-cookbook`.
- **System management:** LDAP/AD auth implementation; Email/SMTP alerting implementation;
  alarm/event lifecycle beyond read-only `Get-DMAlarmHistory`.
- **Docs polish (low priority):** relationship diagrams (would introduce mermaid as a new
  convention); Excel-export polish — a **code** task for `Export-DMStorageToExcel` (its inline
  `#TODO`s: SaveFileDialog, MappingView sheet, performance-report chart templates).

---

## Standing safety reference

Consolidated from the former per-domain TODOs. These rules are permanent, not tasks.

### Not planned / unsafe by default
- **Physical / management surface:** physical port mutation (enable/disable, MTU, speed, IP on
  `eth_port`/`fc_port`); management IP or management-route changes; live `Set-DMLLDPWorkingMode`
  (global, no test-owned variant). High risk of severing management/data access.
- **Identity & security:** changing existing production users or roles; replacing live management
  certificates without a dedicated lab procedure; disabling SNMP/syslog/NTP/DNS/security services.
- **Alarms:** clearing or acknowledging existing alarms without an explicit user request.
- **Storage & data:** deleting/restoring pre-existing LUNs, file systems, shares, snapshots,
  quotas, mappings, or initiators in automated tests; broad or name-pattern cleanup of any object;
  throttling existing production workloads via QoS; live destructive examples without `-WhatIf` or
  an explicit test-owned object.

### Notes for contributors
- **Live workflows use test-owned, ID-tracked resources only.** Clean up by captured ID or exact
  captured name; never broaden cleanup after a failure.
- **Every mutating cmdlet** declares `SupportsShouldProcess`; in-place modifications and deletions
  use `ConfirmImpact = 'High'`. Build request bodies via `ConvertTo-DMRequestBody` so unset
  parameters are never transmitted.
- **New private helper files** must be added to the dot-source whitelist in
  `Tests/Integration/Invoke-GetterIntegrityValidation.ps1`, or cmdlets fail during live validation
  only. Use string-form `[OutputType('OceanstorX')]` — class literals don't resolve on normal
  module import.
- **New getters** must be registered in `Tests/Integration/Private/ReadValidation.ps1` (expected
  output type) and have their output class listed in `Tests/ModuleCoverage.psd1`.
- Global settings (NTP, DNS, time zone, SNMP config) have no safe "undo" — treat any workflow
  touching them with extra scrutiny. Read each domain's `safety-and-live-validation.md` before
  writing or running a mutating cmdlet.

---

*Detailed audit findings live in `ANALYSIS.md`; release-facing summaries in `RELEASE_NOTES.md`.*
