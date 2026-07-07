# Integrity Tests — System Management Coverage

Companion to `Tests/README.md` (runner usage, status meanings) and
`docs/system-management/SAFETY-AND-LIVE-VALIDATION.md` (safety
classification). This page records how the live integrity harness treats the
**system-management** domain as of branch `SystemManageGAP` (2026-07-07).

## What runs read-only

`Tests/Integration/Private/ReadValidation.ps1` validates these getters in
every run:

`Get-DMSystem`, `Get-DMAlarm`, `Get-DMdnsServer`, `Get-DMEquipmentStatus`,
`Get-DMNtpServer`, `Get-DMNtpStatus`, `Get-DMSnmpConfig`,
`Get-DMSnmpSecurityPolicy`, `Get-DMSnmpTrapServer`, `Get-DMSnmpUsmUser`,
`Get-DMSyslogNotification`, `Get-DMLocalUser`, `Get-DMRole`,
`Get-DMRolePermission`, `Get-DMTimeZone`, `Get-DMutcTime`

All 16 system-management getters are registered (`Get-DMTimeZone`,
`Get-DMutcTime`, and `Get-DMEquipmentStatus` were added when finding IT-3
was fixed).

Fixed live defect: `Get-DMRole` list mode used to hang on arrays whose
`role` endpoint pads `range`-paged responses (finding B-1). List mode now
queries the `role` resource unpaged; regression unit tests simulate the
padded-page behavior.

## What is skipped, and how to read the statuses

- **Every run** (read-only and mutating): the system-management mutators
  (users, roles, SNMP, syslog, NTP, time) are listed explicitly as
  `SkippedUnsafe` with the reason that global system-management mutations
  are not exercised by the integrity harness unless a dedicated safe
  workflow exists for them. They no longer fall through to the coverage
  fallback, so mutating runs no longer mislabel them as false `Blocked`
  (finding IT-2, fixed).
- `Blocked` is now reserved for commands whose test-owned prerequisite
  genuinely failed to create during the same mutating run.
- `Set-DMdnsServer` is permanently excluded (`excludedCommands` in
  `MutationValidation.ps1`) and never appears — the intended pattern for
  global-setting mutators.

Interpretation cheat-sheet for the domain:

| You see | It means | Action |
|---|---|---|
| Getter `Passed`/`NoData` | Live read validated | None |
| Workflow mutator `NotRequested` | Read-only run | None |
| Mutator `SkippedUnsafe` | Deliberately never run live (no safe workflow) | None |
| Mutator `Blocked` (mutating run) | A test-owned prerequisite really failed | Investigate the failed prerequisite |
| Getter absent from report | Not registered in `ReadValidation.ps1` | Register it |

## Why global system settings are not mutated

DNS, NTP servers, time zone/UTC time, SNMP protocol/security/community, and
syslog notification settings are **singleton global settings**. There is no
test-owned copy to create and delete: any live mutation rewrites production
behavior (alert delivery, time sync, name resolution, monitoring access).
The harness policy is therefore: unit tests + `-WhatIf` verification for
these mutators; live changes only in a dedicated lab with captured
before-values and an explicit rollback plan.

Discrete, ID-addressed objects (SNMP trap servers, SNMP USM users, and —
with by-address care — syslog server entries) are the only system-management
resources eligible for future test-owned workflows, following the existing
conventions: unique run-prefixed names, immediate ownership registration,
cleanup by captured ID in `finally`, users removed before their role.

## Correction status

1. ~~Fix the `Get-DMRole` paging hang (B-1)~~ — **fixed**: list mode queries
   `role` unpaged; padded-page regression unit tests added.
2. ~~Report system mutators as `SkippedUnsafe` instead of false `Blocked`
   (IT-2)~~ — **fixed** in `MutationValidation.ps1`; classification covered
   by `Tests/Unit/Private/ValidationReporting.Tests.ps1`.
3. ~~Register `Get-DMTimeZone`, `Get-DMutcTime`, `Get-DMEquipmentStatus` in
   `ReadValidation.ps1` (IT-3)~~ — **fixed**.
4. Add an opt-in `SystemManagement` workflow for SNMP trap server + USM user
   lifecycles; keep user/role and syslog sections default-off (IT-1) —
   **still open**.

Full findings: `docs/system-management/VALIDATION-REPORT.md`.
