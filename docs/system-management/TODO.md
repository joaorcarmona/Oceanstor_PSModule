# System Management TODO

This is the roadmap for the **system-management** domain of POSH-Oceanstor:
local users/roles, SNMP, syslog, NTP/time, DNS, certificates, and
alarms/events.

## Current Focus

1. Design and implement a `SystemManagement` mutation workflow.
2. Certificate management research and implementation.
3. Remaining system-management parity gaps (LDAP/AD, alerting, alarms).

## Recently Completed

- `Get-DMRole` list mode no longer hangs on arrays whose `role` endpoint
  pads range-paged responses.
- System-management mutators now report `SkippedUnsafe` instead of a
  false `Blocked` in mutating integrity runs.
- `Get-DMTimeZone`, `Get-DMutcTime`, and `Get-DMEquipmentStatus` are
  registered in read validation.
- DNS cmdlets (`Get-DMdnsServer` / `Set-DMdnsServer`) have unit-test
  coverage.

## High Priority

### 1. SystemManagement mutation workflow

- Add a dedicated `SystemManagement` integration workflow, following the
  same conventions as existing mutation workflows:
  - ownership registry for every created resource
  - cleanup by captured ID only
  - `finally`-block cleanup
  - config gates to enable/disable each section
  - never modifies pre-existing objects
- Cover only safe, test-owned lifecycle objects. Candidate workflows:
  - SNMP trap server create/update/remove
  - SNMP USM user create/update/remove
  - syslog server add/remove by recorded address
  - local role + local user lifecycle (default **off** — see below)
- Local user/role lifecycle is security-sensitive and must default to
  disabled until explicitly reviewed.

### 2. Certificate management

- Research the OceanStor Dorado 6.1.6 REST certificate endpoints.
- Identify a safe, read-only certificate inventory first.
- Implement cmdlets only after the REST schema is confirmed:
  - `Get-DMCertificate`
  - `Import-DMCertificate`
  - `Export-DMCertificate`
  - `Remove-DMCertificate`
  - possibly management certificate replacement, if a safe workflow exists
- Live tests must never replace or delete existing certificates.

## Medium Priority

- LDAP/AD/domain authentication configuration.
- Email/SMTP alert notification.
- Alarm acknowledge/clear and event log query.
- Local login password/security policy.
- Named parameters for syslog severity/facility/port.
- `Get-DMAlarm` date/range filtering.

## Low Priority / Polish

- Typed output class for `Get-DMdnsServer`.
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
