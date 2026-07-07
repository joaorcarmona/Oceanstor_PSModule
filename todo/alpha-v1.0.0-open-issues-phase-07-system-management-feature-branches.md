# alpha-v1.0.0 Open Issues Phase 07 — System-Management Feature Branches (Event Query, LDAP/AD, SMTP)

**Type:** Code + Tests + research (event-query getter is read-only). **Live validation:** none for the
read-only getter; auth/alert mutation would be `SkippedUnsafe` and out of this phase. **Release-blocking:** NO.

## Purpose

Advance the deferred system-management feature branches that are valid but not release-blocking: a
read-only historical alarm/event getter (low risk, fits existing patterns), and the research/scoping
placeholders for LDAP/AD authentication and Email/SMTP alerting. Keep the mutation-heavy auth/alert
surfaces as scoped research, not implementation, until a reviewed design exists.

## Source TODOs / evidence

- `docs/system-management/TODO.md`:
  - Medium Priority "Alarm acknowledge/clear and event query" — **Event query: future feature branch
    (read-only, low risk)**. Historical alarms via `GET alarm/historyalarm` (§4.2.2.4.7), same
    filter surface `Get-DMAlarm` already uses for `alarm/currentalarm`. Suggested shape:
    `Get-DMAlarm -History` or `Get-DMEvent`.
  - Medium Priority — LDAP/AD/domain authentication; Email/SMTP alert notification; local login
    password/security policy (all `open` future branches, research placeholders only).
  - Future Feature Branches table — LDAP/AD (auth-sensitive, High), Email/SMTP (Medium),
    Alarm/event lifecycle (Medium/High).

## Current repository evidence

- `Get-DMAlarm` already supports `-StartTime`/`-EndTime`/`-Last`/`-AlarmStatus` against
  `alarm/currentalarm` — the historical variant reuses that filter surface against a different
  endpoint.
- No LDAP/AD, SMTP, or password-policy cmdlets exist (documented as not implemented).

## Scope

- Implement the read-only historical alarm/event getter (`Get-DMAlarm -History` **or** `Get-DMEvent`,
  pick one and stay consistent), typed output, unit tests, read-validation registration.
- LDAP/AD and Email/SMTP: produce a scoped research note (endpoints, safety posture, proposed
  cmdlet shapes) — **no implementation** in this phase.

## Out of scope

- **Alarm acknowledge** — rejected (no endpoint). **Alarm clear** — deferred (needs a safe
  test-alarm generator); both belong to the alarm/event lifecycle branch, not here.
- Any authentication or alerting **mutation** cmdlet (LDAP/AD join, SMTP config, password policy) —
  security-sensitive, research-only in this phase.
- Live mutation of any kind.

## Implementation tasks

1. Add the historical getter reusing `Get-DMAlarm`'s filter parameters against `alarm/historyalarm`;
   typed output class; mock unit tests; register in `ReadValidation.ps1`; export in manifest +
   ModuleCoverage.
2. Write a research note for LDAP/AD and Email/SMTP: documented endpoints, blast radius, proposed
   `SupportsShouldProcess`/`ConfirmImpact` posture, and open decisions — as a future-branch scoping
   doc, not code.

## Files likely to inspect

- `POSH-Oceanstor/Public/Get-DMAlarm.ps1`, its class + tests
- `Tests/Integration/Private/ReadValidation.ps1`, `POSH-Oceanstor/POSH-Oceanstor.psd1`,
  `Tests/ModuleCoverage.psd1`
- `OceanStor Dorado 6.1.6 REST Interface Reference.md` §4.2.2.4.7 (historyalarm) + LDAP/SMTP sections

## Files likely to modify

- New historical getter cmdlet + class + unit test; read-validation registration; manifest +
  ModuleCoverage exports; a new research note under `.archived-commands/` or `docs/system-management/`.

## Safety considerations

- The historical getter is **read-only** — no mutation, safe for default live read validation.
- LDAP/AD and SMTP are authentication/alerting-sensitive; keep them research-only until a reviewed
  design exists. No live array access in this phase.

## Testing strategy

- Mock-based unit tests for the historical getter (filter passthrough, typed output, empty-result
  handling). No live execution.

## Verification commands

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal
Get-Command -Module POSH-Oceanstor | Where-Object Name -match 'Event|Alarm'
```

## Dependencies

- New export must be reflected in `POSH-Oceanstor.psd1` and `Tests/ModuleCoverage.psd1`.
- Independent of the release-blocker phases.

## Completion criteria

- Read-only historical alarm/event getter shipped, unit-tested, exported, read-validation-registered.
- LDAP/AD and Email/SMTP have a scoped research note; neither is implemented.
- Alarm acknowledge stays rejected; alarm clear stays deferred.

## Risks / notes

- Keep naming consistent with the existing `Get-DMAlarm` surface to avoid a confusing duplicate
  getter; decide `-History` switch vs separate `Get-DMEvent` up front.
