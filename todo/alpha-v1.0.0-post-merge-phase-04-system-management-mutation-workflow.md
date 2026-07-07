# alpha-v1.0.0 Post-Merge Phase 04 — SystemManagement Mutation Workflow

## Purpose

Design and implement the dedicated, config-gated `SystemManagement` integration workflow
so the safe subset of system-management mutators can finally be exercised live against
test-owned objects, instead of remaining permanently `SkippedUnsafe`. Also scope (and
decide on) the alarm acknowledge/clear + event-query surface.

## Source TODOs / evidence

- `docs/system-management/TODO.md` § High Priority 1 "SystemManagement mutation workflow":
  ownership registry, cleanup by captured ID only, `finally`-block cleanup, config gates,
  never modifies pre-existing objects. Candidate workflows: SNMP trap server, SNMP USM
  user, syslog server add/remove by recorded address, local role+user lifecycle
  (default **off**, security-sensitive).
- `docs/system-management/safety-and-live-validation.md` — category table; global
  settings have no safe undo; `SkippedUnsafe` policy.
- `docs/testing/system-management-integrity-tests.md` — current state: system mutators
  report `SkippedUnsafe`; `Blocked` reserved for real prerequisite failures.
- `docs/system-management/TODO.md` (LDAP/AD, Email/SMTP, alarm acknowledge/clear,
  password/security policy — compressed remnants of the parity-gap list).

Deduplication decision:
Live validation of the workflows built here is *this* phase's completion evidence — the
general testing phases (02, 09) must not re-list "run the SystemManagement workflow" as
their own task. Syslog **named parameters** are Phase 03; this phase only adds the syslog
**server add/remove lifecycle** to the harness. LDAP/AD and Email/SMTP remain future
feature branches (per the TODO's branch table) — planned here only as research
placeholders, not implementation.

## Scope

- [Code] New `Tests/Integration/Private/Workflows/SystemManagement.ps1` following the
  existing `Workflows/*.ps1` pattern (LunGroup.ps1 as reference): config gate section,
  ownership registry, ID-captured cleanup in `finally`.
- [Code] Sub-workflows, each individually config-gated:
  1. SNMP trap server: create → update → remove (test-owned address).
  2. SNMP USM user: create → update → remove (unique test prefix).
  3. Syslog server: add → remove by the exact recorded address.
  4. Local role + local user lifecycle — implemented but default **disabled**
     (`SystemManagement.AllowLocalUserLifecycle = $false`) until explicitly reviewed.
- [Safety review] Confirm each sub-workflow mutates only objects it created; existing
  SNMP/syslog/user/role config is never touched, listed, matched by name pattern, or
  "cleaned".
- [Tests] Unit tests for any new/changed public cmdlet paths the workflow exposes as
  missing; `-WhatIf` no-API-call assertions for the involved mutators if absent.
- [Live-validation planning] Plan (do not run now) a gated lab run: internal planning may
  reference `$storageIP = '10.10.10.24'` with
  `$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"`; the array
  requires `-SkipCertificateCheck`.
- [Safety review] Alarm ack/clear + event query: research the REST endpoints and decide
  whether acknowledge (non-destructive metadata) is admissible on a test-generated alarm
  only, or stays Not Planned. Output of this task is a written decision in
  `docs/system-management/TODO.md`, not code, unless the decision is clearly safe.

## Out of scope

- NTP, DNS, time zone, security policy, certificate mutation — global settings with no
  safe undo; remain `SkippedUnsafe` (certificates: Phase 05).
- LDAP/AD, Email/SMTP implementation.
- Changing existing users, roles, SNMP, syslog config — forbidden, ever.

## Implementation tasks

- [Code] Workflow file with per-section config gates
  (`SystemManagement.Enabled`, `.AllowSnmpTrapServer`, `.AllowSnmpUsmUser`,
  `.AllowSyslogServer`, `.AllowLocalUserLifecycle` — names to match existing config
  conventions in the harness).
- [Code] Ownership registry entries with immediate ID capture after each create;
  cleanup deletes by captured ID only; failed cleanup reported loudly in the run report.
- [Code] Register the workflow in `Invoke-GetterIntegrityValidation.ps1`; add any new
  Private helpers to the dot-source whitelist.
- [Tests] `-WhatIf` regression tests for the SNMP/syslog/user/role mutators exercised by
  the workflow (assert zero `Invoke-DeviceManager` calls under `-WhatIf`).
- [Docs-only] Update `docs/system-management/safety-and-live-validation.md` and
  `docs/testing/system-management-integrity-tests.md` with the new categories/gates.
- [Live-validation planning] Written runbook: prerequisites, unique test prefix (e.g.
  `POSHTEST-`), expected report statuses, rollback expectations.

## Files likely to inspect

- `Tests/Integration/Private/Workflows/*.ps1` (pattern), `ValidationHelpers` ownership
  functions (`Update-TestOwnedResourceIdentity`, `Invoke-OwnedRemoval`)
- `POSH-Oceanstor/Public/*Snmp*`, `*Syslog*`, user/role cmdlets
- `OceanStor Dorado 6.1.6 REST Interface Reference.md` (SNMP/USM/syslog/user endpoints)

## Files likely to modify

- New `Tests/Integration/Private/Workflows/SystemManagement.ps1`
- `Tests/Integration/Invoke-GetterIntegrityValidation.ps1` (registration + whitelist)
- Unit test files for `-WhatIf` coverage
- `docs/system-management/TODO.md`, `safety-and-live-validation.md`,
  `docs/testing/system-management-integrity-tests.md`

## Safety considerations

- Query read-only freely; create only test-owned objects with a unique prefix; capture
  IDs immediately; register cleanup immediately; cleanup in `finally`; delete by captured
  ID, never name matching; report failed cleanup clearly.
- Never mutate existing users, roles, authentication config, SNMP, syslog, NTP, DNS,
  certificates, or any object not created in the same run.
- Local user/role lifecycle ships disabled; enabling it is an explicit reviewed decision.
- No live commands during this phase's development; the first live run is a separately
  scheduled, human-supervised event.

## Testing strategy

1. Unit tests (mocked REST) for all workflow-called cmdlet paths and `-WhatIf`.
2. Static: ScriptAnalyzer on new files; harness dry-run in `NotConfigured` mode (all
   gates off) to confirm clean `NotConfigured`/`SkippedUnsafe` reporting.
3. Later, human-triggered: gated live run on the lab array per the runbook.

## Verification commands

```powershell
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
git diff --check; git diff --stat
```

## Dependencies

- Phase 02 strongly recommended first (so the new workflow's unexecuted commands report
  `NotRequested`/`NotConfigured` correctly, not false `Blocked`).
- Phase 03 (syslog parameter surface settled before the harness exercises it).

## Completion criteria

- Workflow merged, disabled by default, all gates `NotConfigured` in a default run.
- `-WhatIf` unit coverage exists for every mutator the workflow touches.
- Runbook exists; alarm ack/clear decision recorded in the TODO.

## Risks / notes

- SNMP USM user and local user creation may be rejected by array security policy
  (password complexity, user count limits) — the workflow must treat policy rejection as
  a reported, non-fatal outcome, not a harness failure.
- The TODO's branch table rates this Fable/Opus-High effort: safety-sensitive design.
