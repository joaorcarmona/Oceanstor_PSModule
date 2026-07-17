# System Management TODO

This is the roadmap for the **system-management** domain of POSH-Oceanstor:
local users/roles, SNMP, syslog, NTP/time, DNS, certificates, and
alarms/events.

## Current Focus

1. Human-supervised gated lab run of the new `SystemManagement` mutation
   workflow (implementation landed in Phase 04; see the runbook in
   `docs/testing/system-management-integrity-tests.md`).
2. Certificate management Stage B (mutation surface) — deferred; see
   High Priority item 2 for the per-cmdlet reasons. Stage A (read-only
   inventory) shipped in Phase 05.
3. Remaining system-management parity gaps (LDAP/AD, alerting, alarms).

## High Priority

> Deduplication note: item 1 (mutation workflow, including the alarm
> ack/clear decision) is scoped in
> `todo/alpha-v1.0.0-post-merge-phase-04-system-management-mutation-workflow.md`;
> item 2 (certificates) is scoped in
> `todo/alpha-v1.0.0-post-merge-phase-05-certificate-management.md`. Item 1
> implemented and its SNMP-trap surface exercised in a supervised live run
> (Phase 03, 2026-07-07 — create/cleanup validated, update/test defect `50331651`
> recorded as item 4); the alarm ack/clear decision recorded on
> 2026-07-07; item 2 Stage A implemented on 2026-07-07
> (`Get-DMCertificate`), Stage B deferred.

### 3. SNMP USM user credential-parameter analyzer finding — RESOLVED (Phase 01, 2026-07-07)

- Phase 11's release-gate run (2026-07-07) surfaced 2 PSScriptAnalyzer
  **Error**-severity `PSAvoidUsingUsernameAndPasswordParams` findings on
  `New-DMSnmpUsmUser.ps1` and `Set-DMSnmpUsmUser.ps1` (line 10 of each).
- **Decision (Phase 01): justified suppression, not redesign.** SNMPv3 USM has a
  two-secret model (separate auth + privacy passphrases) plus a USM user name,
  which cannot be expressed as a single `[PSCredential]` (one username / one
  password). `[SecureString]` input is already accepted on both cmdlets and
  normalized via `ConvertFrom-DMSensitiveValue`, and secret values are never
  printed or logged; the cmdlets also accept plaintext for compatibility (a
  documented, tested contract). Forcing `SecureString`-only would be a breaking
  public-parameter change for no additional protection. A narrow, documented
  `[Diagnostics.CodeAnalysis.SuppressMessageAttribute]` for
  `PSAvoidUsingUsernameAndPasswordParams` (and the co-located
  `PSAvoidUsingPlainTextForPassword`) was added to both cmdlets with a
  justification. The release gate now reports **0 Error-severity findings**.
- See `RELEASE_NOTES.md` and `todo/release-readiness-go-no-go.md` for the
  recorded decision.

### 1. SystemManagement mutation workflow — implemented (Phase 04); SNMP-trap surface exercised live (Phase 03, 2026-07-07)

- The dedicated `SystemManagement` integration workflow exists at
  `Tests/Integration/Private/Workflows/SystemManagement.ps1`, following the
  same conventions as existing mutation workflows:
  - ownership registry for every created resource
  - cleanup by captured ID (or exact recorded syslog address) only
  - registered cleanup that runs at end-of-run even when steps fail
  - per-section config gates, all disabled by default
  - never modifies pre-existing objects
- Implemented sub-workflows (each gated in `IntegrityValidationConfig.psd1`):
  - SNMP trap server create/update/test/remove (`AllowSnmpTrapServer`)
  - SNMP USM user create/update/remove (`AllowSnmpUsmUser`)
  - syslog server add/remove by recorded address (`AllowSyslogServer`)
  - local role + local user lifecycle (`AllowLocalUserLifecycle`, default
    **off** — security-sensitive, enabling it is an explicit reviewed
    decision)
- **Live validation (Phase 03, 2026-07-07, the lab array, human-supervised,
  one gate only — `SystemManagement.Enabled` + `AllowSnmpTrapServer`; USM,
  syslog, and local-user lifecycle stayed off):**
  - Read-only baseline `Blocked=0, Failed=0`; post-run read-only `Blocked=0,
    Failed=0` with `Get-DMSnmpTrapServer` back to its prior count and no leftover
    test objects. No pre-existing SNMP/syslog/user/role object touched.
  - `New-DMSnmpTrapServer` — **Passed** (test-owned object created, run-unique ID
    captured immediately).
  - `Set-DMSnmpTrapServer` (update) — **Failed**: `OceanStor API error 50331651:
    The entered parameter is incorrect.`
  - `Test-DMSnmpTrapServer` (send trap) — **Failed**: same `50331651` error.
  - `Remove-DMSnmpTrapServer` — **Passed**: registered cleanup removed the object
    by captured ID despite the mid-workflow failures (`finally`/LIFO cleanup
    worked as designed).
  - **Outcome: create + registered cleanup *Validated*; update/test-trap is a
    defect (`50331651`) — tracked as High Priority #4 below and routed to the
    owning SystemManagement domain (Phase 04 cmdlet/workflow), not Phase 03.**
- **Remaining live runs executed 2026-07-09 (lab array, run ID 20260709033729,
  all `SystemManagement` gates enabled in config; no leftovers, no pre-existing
  SNMP/syslog/user/role object touched):**
  - `AllowSnmpUsmUser` — **Passed end-to-end**: `New-DMSnmpUsmUser`, read-back,
    `Set-DMSnmpUsmUser`, read-back, and `Remove-DMSnmpUsmUser` by captured ID all
    green on a run-unique user with generated throwaway secrets.
  - `AllowSyslogServer` — **Resolved (root cause found + fix landed, live-confirmed
    2026-07-17)**: the `50331651` was a field-name error, not a missing field. Per
    REST reference §4.2.2.1.1/§4.2.2.2.1 the mandatory field is
    `CMO_ALARM_SYSLOG_SERVER_IP`, but `Add-DMSyslogServer`/`Remove-DMSyslogServer`
    sent `CMO_SYSLOG_SERVER_IP`. Corrected both cmdlets; the read model
    (`class-OceanStorSystemConfiguration.ps1`) also now reads
    `CMO_ALARM_SYSLOG_SERVER_IP`, fixing the read-back verify. Add/read-back/remove
    all **Passed** live.
  - `AllowLocalUserLifecycle` — **Resolved (root cause found + fix landed, live-confirmed
    2026-07-17)**. Two independent `50331651` causes:
    - `New-DMRole`: the create body carried `roleSource` (a response-only field per
      REST reference §4.3.6.1.1) and no `permitList`. `New-DMRole` now exposes a
      `-PermitList` parameter; the workflow supplies a minimal `lun:lun_R;` permission
      and omits `roleSource` on create.
    - `New-DMLocalUser`: the create body omitted the mandatory `SCOPE` field and used
      camel-case `roleId` instead of `ROLEID` (REST reference, Creating a User).
      `New-DMLocalUser` now defaults `SCOPE = '0'` (local user) and sends `ROLEID`.
    Full role + user create/set/remove lifecycle **Passed** live.

### 2. Certificate management — Stage A done (Phase 05), Stage B deferred

- Done (2026-07-07): REST endpoint research recorded in
  `.archived-commands/certificate-endpoint-research.md` (source: REST
  Interface Reference section 4.3.5); `Get-DMCertificate` read-only
  inventory implemented against the documented `GET certificate` endpoint
  (4.3.5.3.1) with typed `OceanStorCertificate` output, unit tests, and
  read-validation registration.
- Deferred (Stage B mutation surface):
  - `Import-DMCertificate` — **blocked on vendor documentation**: the 6.1.6
    reference documents activation of an already-uploaded certificate file
    (`PUT certificate/active`) but not the certificate upload step itself.
  - `Export-DMCertificate` — deferred: the download endpoint
    (`GET file/certificate?path=...`) is path-addressed with unspecified
    path semantics and an unquantified private-key retrieval risk.
  - `Remove-DMCertificate` — endpoint documented
    (`DELETE om_msg_op_delete_certificate_info`) but deferred pending an
    approved human-run lab-safe procedure (see the memo's lab-only
    replacement procedure).
- If Stage B is ever built: `SupportsShouldProcess`,
  `ConfirmImpact = 'High'`, permanently `SkippedUnsafe` in live validation.
- Live tests must never replace or delete existing certificates.

### 4. `Set-DMSnmpTrapServer` / `Test-DMSnmpTrapServer` reject update payload — API error 50331651 (found Phase 03, 2026-07-07 — **root cause identified; `Test` closed live 2026-07-09; `Set` read-modify-write fix + unit tests landed 2026-07-17; awaiting `Set` live re-confirm**)

- **Root cause (static analysis, 2026-07-09):** confirmed against the in-repo
  `OceanStor Dorado 6.1.6 REST Interface Reference.md`. Two independent body-field
  omissions, both rejected as `50331651`:
  - Modify (`PUT snmp_trap_addr/{id}`, §4.2.1.3.1) marks **`ID` as a Mandatory body
    field** (the reference request example includes `"ID": "2"`), but
    `Set-DMSnmpTrapServer` only sent the ID in the URL path.
  - Send-test (`PUT snmp_trap_addr/send_test_trapmsg`, §4.2.1.5.x) marks
    **`CMO_TRAP_SERVER_TYPE` and `CMO_TRAP_VERSION` as Mandatory**, but
    `Test-DMSnmpTrapServer` sent them only when the caller supplied `-Type`/`-Version`.
- **Fix (2026-07-09):** `Set-DMSnmpTrapServer` now always adds `$body.ID = $Id`;
  `Test-DMSnmpTrapServer` now always sends `CMO_TRAP_SERVER_TYPE`/`CMO_TRAP_VERSION`,
  defaulting to the REST-documented create defaults (type `3`/All, version `1`/SNMPv1)
  when omitted. Mock-based unit tests added
  (`Tests/Unit/Public/Set-DMSnmpTrapServer.Tests.ps1`,
  `Tests/Unit/Public/Test-DMSnmpTrapServer.Tests.ps1`) asserting the corrected request
  bodies. `ShouldProcess`/`-WhatIf` behavior on `Set` is unchanged and still covered.
- **Live re-confirm (2026-07-09, run ID 20260709033729): partially resolved.**
  `Test-DMSnmpTrapServer` now **Passed** live — `50331651` is gone and the test
  trap sends against the test-owned address; that half of the defect is closed.
  `Set-DMSnmpTrapServer` no longer returns `50331651` either, but now fails with
  `OceanStor API error 1077949001: The message has timed out` (PUT took ~50 s,
  read-back shows the port unchanged). Two candidate causes, unresolved
  (`NeedsInvestigation`): (a) the mutation trace shows the PUT body carries only
  `ID` + `CMO_TRAP_SERVER_PORT`, while the spec marks
  `CMO_TRAP_SERVER_IP`/`PORT` Mandatory on every `PUT` — the array may stall on
  a partial-field update; (b) the test-owned trap target is the unreachable
  TEST-NET-1 documentation address, and the array may probe it during modify.
  Next step: have `Set-DMSnmpTrapServer` re-supply the full mandatory field set
  (read-modify-write), then live re-confirm. Cleanup by captured ID succeeded;
  no leftovers.
- **Code fix landed (2026-07-17):** `Set-DMSnmpTrapServer` now performs a
  read-modify-write — it re-reads the current server via `Get-DMSnmpTrapServer -Id`
  inside the `ShouldProcess` block and re-supplies the full mandatory field set
  (`ID` + `CMO_TRAP_SERVER_IP` + `CMO_TRAP_SERVER_PORT`, plus USM/type/version),
  overlaying only the fields the caller explicitly passed. This resolves candidate
  cause (a) — the array no longer receives a partial-field `PUT`. Mock unit tests
  in `Tests/Unit/Public/Set-DMSnmpTrapServer.Tests.ps1` now assert the mandatory
  IP/PORT are re-supplied from the read-back when only `-Id` (or `-Id -Port`) is
  given (regression guard for `1077949001`). **Still `NeedsInvestigation`:**
  candidate cause (b) — the unreachable TEST-NET-1 target — can only be ruled out
  by a supervised live re-confirm against reachable lab hardware (Phase 2 SNMP gate).
- Surfaced by the first supervised SNMP-trap live run (see High Priority #1). On
  the lab array, `New-DMSnmpTrapServer` and `Remove-DMSnmpTrapServer` succeed,
  but `Set-DMSnmpTrapServer` (update) and `Test-DMSnmpTrapServer` (send test trap)
  both fail with `OceanStor API error 50331651: The entered parameter is
  incorrect.`
- Likely an update/test request-body field mismatch against this array's REST
  contract (create path works, update/test path does not). Investigate the
  parameter set / body construction in the owning cmdlets against the 6.1.x SNMP
  trap-server REST reference; confirm whether the array firmware version rejects a
  specific field on `PUT`/test.
- **Owning domain: SystemManagement (Phase 04 workflow/cmdlet).** Out of scope for
  Phase 03 (evidence-gathering only). No workflow code changed here — recorded and
  routed. Cleanup was unaffected: the created object was removed by captured ID.

### 5. `Set-DMRole` modify rejects payload — missing Mandatory `id` body field (static analysis 2026-07-17)

- Sibling defect to High Priority #4 and the network `Set-DMvLan`/`Set-DMFailoverGroup`
  fixes: the modify interface (`PUT role/{id}`, REST reference §4.3.6.3.1) marks **`id`
  (lowercase) as a Mandatory body field**; `name`/`description` are Optional (and cannot be
  changed concurrently). The doc's terse example body omits `id`, but the Parameters table
  is the contract, so sending `description`/`name` alone (id only in the URL path) is
  rejected as `50331651`.
- **Fix (2026-07-17, static analysis only):** `Set-DMRole` now echoes `$body.id = $Id`
  (lowercase, matching the role interface's field casing) alongside the URL path. Unit
  assertion added to `Tests/Unit/Public/Set-SystemConfiguration.Tests.ps1` (the "creates,
  modifies, and removes roles" test). **Live-confirmed 2026-07-17 against a V600R005C27
  lab array (10.10.10.24): a throwaway role was created, its description modified via
  `Set-DMRole` (accepted — no `50331651`), read back, and removed by captured ID; array
  state restored, no leftovers.**
- Note: `Set-DMLocalUser` (`PUT user/{id}`, §4.3.1.3.3) omits `ID` from the body too, but
  there the field is **Conditional** (required only when a super-administrator modifies
  another user), so it is recorded here as an audit note rather than fixed in this pass.

## Medium Priority

> Deduplication note: LDAP/AD and Email/SMTP remain `open` future feature
> branches per Phase 04's dedup decision (research placeholders only, no
> implementation phase yet). Phase 07 added a scoped research/scoping note —
> documented endpoints, blast radius, proposed cmdlet shapes, and
> `SupportsShouldProcess`/`ConfirmImpact` posture — at
> `docs/system-management/ldap-ad-smtp-alerting-research.md`. No code was
> implemented for any of these in Phase 07.

- LDAP/AD/domain authentication configuration. — research only; auth-sensitive,
  `ConfirmImpact=High`, mock-only first, live validation `SkippedUnsafe`.
- Email/SMTP alert notification. — research only; alerting-sensitive,
  `ConfirmImpact=Medium`/`High`, mock-only first, live validation `SkippedUnsafe`.
- Local login password/security policy. — research only; no dedicated documented
  endpoint found (only SNMP security policy exists), `ConfirmImpact=High`.

### Alarm acknowledge/clear and event query — decision (Phase 04, 2026-07-07)

Researched against the OceanStor Dorado 6.1.6 REST Interface Reference:

- **Alarm acknowledge: not planned.** The 6.1.6 reference documents no
  acknowledge/confirm endpoint — `confirmTime` appears only as a read-only
  field on `alarm/currentalarm` query results. There is nothing safe to
  implement against.
- **Alarm clear: cmdlet implemented, live validation still deferred.** The
  endpoint is documented (`DELETE alarm/currentalarm?sequence=<sn>`, section
  4.2.2.5.1) but clearing removes the alarm record, which is destructive on any
  real alarm. As of Phase 04 no cmdlet existed; the `Clear-DMAlarm` cmdlet was
  subsequently implemented (commit `f48845b`) with `-WhatIf`/`ConfirmImpact =
  High` guards, clearing by captured sequence number only. **Live validation
  remains deferred**: the integrity harness still has no safe, deterministic way
  to *generate* a test alarm, so `Clear-DMAlarm` must not be exercised live yet.
  If an alarm/event feature branch later adds a reliable test-alarm generator,
  clear may be exercised against that test-generated alarm's captured sequence
  number only — never against pre-existing alarms.
- **Event query: implemented read-only in Phase 07 (2026-07-08).** Historical
  alarms/events are queried via `GET alarm/historyalarm` (section 4.2.2.4.7)
  through the dedicated cmdlet **`Get-DMAlarmHistory`**. Naming decision: a
  separate getter was chosen over `Get-DMAlarm -History` because history exposes
  a broader server-side filter surface (level, alarm status, entry type, alarm
  object type, single/ranged sequence number) than current-alarm filtering, and
  it defaults to the last 7 days to avoid a full-history scan. It returns typed
  `OceanStorAlarm` objects, is exported in the manifest, unit-tested, and
  registered in read validation. `Get-DMAlarm` (current alarms, `alarm/
  currentalarm`) is unchanged.

## Low Priority / Polish

- More usage examples across the domain docs.
- Additional Excel export polish where relevant.
- Test/report schema polish.

## Testing and Validation

- Unit tests remain mandatory for every new cmdlet.
- Mutators require `ShouldProcess` (`-WhatIf` / `-Confirm`).
- Live mutation tests must be opt-in and config-gated.
- Global system settings are reported `SkippedUnsafe` unless a safe,
  reversible workflow exists for them.
- Any live workflow only touches test-owned resources.
- Cleanup is always by captured ID — never a broad sweep.
- No workflow may change existing users, roles, SNMP, syslog, NTP, DNS,
  or certificates.

## Documentation

Docs to maintain as the domain evolves:

- `docs/system-management/`
- `docs/testing/`
- `Tests/README.md`

## Future Feature Branches

| Branch | Recommended Model | Effort | Reason |
|---|---|---|---|
| SystemManagement mutation workflow | Fable or Opus | High | Safety-sensitive live mutation design |
| Certificate management | Fable or Opus | High | REST research + risk of management certificate changes |
| LDAP/AD auth | Fable or Opus | High | Authentication/security-sensitive |
| Email/SMTP alerts | Sonnet | Medium | Lower risk than auth/certs, but alerting-sensitive |
| Alarm/event lifecycle | Sonnet or Fable | Medium/High | Depends on whether mutating alarm actions are included |
| Polish items | Sonnet | Medium | Mechanical docs/tests/output improvements |

## Not Planned / Unsafe by Default

- Changing existing production users.
- Changing existing roles.
- Replacing live management certificates without a dedicated lab procedure.
- Disabling SNMP/syslog/NTP/DNS/security services.
- Clearing or acknowledging existing alarms without an explicit user request.
- Broad/unscoped cleanup of array state.

## Notes for Contributors

- Read [safety-and-live-validation.md](safety-and-live-validation.md)
  before writing or running any mutating cmdlet in this domain.
- Prefer test-owned, ID-tracked resources for any live workflow.
- Global settings (NTP, DNS, time zone, SNMP config) have no safe
  "undo" — treat any workflow touching them with extra scrutiny.
