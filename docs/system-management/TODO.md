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

## Recently Completed

- Phase 05 Stage A: certificate REST research
  (`.archived-commands/certificate-endpoint-research.md`) and read-only
  inventory getter `Get-DMCertificate` with typed `OceanStorCertificate`
  output, unit tests, and read-validation registration. Stage B (mutation)
  deferred: import is blocked on vendor documentation (no documented
  certificate upload interface), export/remove deferred pending an approved
  lab-safe procedure; certificate mutation stays permanently `SkippedUnsafe`.

- Phase 04: config-gated `SystemManagement` integration workflow
  (`Tests/Integration/Private/Workflows/SystemManagement.ps1`) covering
  SNMP trap server, SNMP USM user, syslog server, and (default-off)
  local role/user lifecycles — all gates disabled by default, cleanup by
  captured ID or exact recorded address only. Not yet exercised live.

- `Get-DMRole` list mode no longer hangs on arrays whose `role` endpoint
  pads range-paged responses.
- System-management mutators now report `SkippedUnsafe` instead of a
  false `Blocked` in mutating integrity runs.
- `Get-DMTimeZone`, `Get-DMutcTime`, and `Get-DMEquipmentStatus` are
  registered in read validation.
- DNS cmdlets (`Get-DMdnsServer` / `Set-DMdnsServer`) have unit-test
  coverage.
- `Get-DMAlarm` supports `-StartTime`/`-EndTime`/`-Last` date/range
  filtering alongside `-AlarmStatus`.
- `Set-DMSyslogNotification` exposes named `-Severity`/`-Port`/`-Protocol`
  parameters (no `-Facility`: no such field exists in the REST syslog
  resource). `Add-DMSyslogServer` confirmed to have no per-server
  severity/port/protocol fields, by design.
- `Get-DMdnsServer` returns typed `OceanStorDnsServer` objects instead of
  an untyped hashtable.

## High Priority

> Deduplication note: item 1 (mutation workflow, including the alarm
> ack/clear decision) is scoped in
> `todo/alpha-v1.0.0-post-merge-phase-04-system-management-mutation-workflow.md`;
> item 2 (certificates) is scoped in
> `todo/alpha-v1.0.0-post-merge-phase-05-certificate-management.md`. Item 1
> implemented (live run pending) and the alarm ack/clear decision recorded on
> 2026-07-07; item 2 Stage A implemented on 2026-07-07
> (`Get-DMCertificate`), Stage B deferred.

### 3. SNMP USM user credential-parameter analyzer finding — release blocker, unowned

- Phase 11's release-gate run (2026-07-07) surfaced 2 PSScriptAnalyzer
  **Error**-severity `PSAvoidUsingUsernameAndPasswordParams` findings on
  `New-DMSnmpUsmUser.ps1` and `Set-DMSnmpUsmUser.ps1` (line 10 of each).
  These block the release pipeline's hard analyzer gate
  (`-FailOnAnalyzerIssue` in `.github/workflows/release.yml`). Not fixed by
  Phase 11 (no production cmdlet code changes in scope) — needs a future
  system-management pass to redesign the affected parameters (e.g.
  `[PSCredential]`/`SecureString` instead of separate plaintext
  username/password parameters) without breaking the documented SNMPv3 USM
  user contract. See `todo/release-readiness-go-no-go.md` for the full
  release-gate finding.

### 1. SystemManagement mutation workflow — implemented (Phase 04), live run pending

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
- Remaining: the first live validation run is a separately scheduled,
  human-supervised event — see the gated lab-run runbook in
  `docs/testing/system-management-integrity-tests.md`.

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

## Medium Priority

> Deduplication note: LDAP/AD and Email/SMTP remain `open` future feature
> branches per Phase 04's dedup decision (research placeholders only, no
> implementation phase yet).

- LDAP/AD/domain authentication configuration.
- Email/SMTP alert notification.
- Local login password/security policy.

### Alarm acknowledge/clear and event query — decision (Phase 04, 2026-07-07)

Researched against the OceanStor Dorado 6.1.6 REST Interface Reference:

- **Alarm acknowledge: not planned.** The 6.1.6 reference documents no
  acknowledge/confirm endpoint — `confirmTime` appears only as a read-only
  field on `alarm/currentalarm` query results. There is nothing safe to
  implement against.
- **Alarm clear: future feature branch, safe only for test-generated
  alarms.** The endpoint is documented (`DELETE alarm/currentalarm?
  sequence=<sn>`, section 4.2.2.5.1) but clearing removes the alarm record,
  which is destructive on any real alarm. The integrity harness has no safe,
  deterministic way to *generate* a test alarm today, so no `Clear-DMAlarm`
  cmdlet or workflow is implemented in Phase 04. If an alarm/event feature
  branch later adds a reliable test-alarm generator, clear may be exercised
  against that test-generated alarm's captured sequence number only — never
  against pre-existing alarms.
- **Event query: future feature branch (read-only, low risk).** Historical
  alarms/events are queryable via `GET alarm/historyalarm` (section
  4.2.2.4.7) with the same filter surface `Get-DMAlarm` already uses for
  `alarm/currentalarm`. A read-only getter (e.g. `Get-DMAlarm -History` or
  `Get-DMEvent`) fits existing module patterns and belongs in the
  alarm/event lifecycle feature branch, not Phase 04.

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
