# System Management Validation Report

> Date: 2026-07-07 · Analyst: automated analysis (Claude Fable 5, high
> reasoning) · Lab array: `StorageIP` (internal lab, read-only access only)

> **Correction status (2026-07-07, same branch):** B-1, IT-2, IT-3, and
> UT-1 below have been fixed. `Get-DMRole` list mode now queries `role`
> unpaged (with padded-page regression unit tests;
> `Invoke-DMPagedRequest` untouched); system-management mutators are
> reported `SkippedUnsafe` instead of false `Blocked`; `Get-DMTimeZone`,
> `Get-DMutcTime`, and `Get-DMEquipmentStatus` are registered in
> `ReadValidation.ps1`; and the DNS pair has unit tests. IT-1 (a
> `SystemManagement` mutation workflow) and F-1..F-8 remain open. The
> body below is preserved as the original point-in-time analysis, with
> per-finding fix notes.

## Summary

The `SystemManageGAP` branch closes most of the system-management gap named
in the repository gap analysis: 44 cmdlets across local users, roles, SNMP,
syslog, NTP/time, DNS, and read-only system/alarm queries, all with
`ShouldProcess` on mutators, pipeline support, typed outputs, and strong
unit-test coverage. Live read-only validation passed for 15 of 16 getters
and exposed **one implementation bug** (`Get-DMRole` list mode hangs on
arrays whose `role` endpoint pads range-paged responses) and **one
integrity-harness reporting defect** (system mutators misreported as
`Blocked` in mutating runs). Certificate management, LDAP/AD auth,
email/SMTP alerting, alarm lifecycle, and event queries remain unimplemented.
No mutations were performed; no objects were created.

## Branch / Git State

- Branch: `SystemManageGAP`, clean working tree at analysis start
  (HEAD `6115ac8`).
- Relevant commits: `3ef7907` (close system management gap), `0476768`
  (document + Excel export), `6f82f46` (equipment and time cmdlets).

## Sources Reviewed

- `.archived-commands/GAP_Analysis.md` (source gap analysis, 2026-07-05)
- `POSH-Oceanstor/Public/*.ps1` (44 system-management cmdlets)
- `POSH-Oceanstor/Private/class-OceanStorSystemConfiguration.ps1`,
  `Invoke-DMPagedRequest.ps1`, `class-OceanstorViewStorage.ps1`
- `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1`,
  `Set-SystemConfiguration.Tests.ps1`
- `Tests/Integration/` (runner, config, `ReadValidation.ps1`,
  `MutationValidation.ps1`, `Reporting.ps1`, all 11 workflow files)
- `Tests/README.md`, `README.md`
- `Reports/getter-integrity-last-result.json` (harness run of 2026-07-06)

## Cmdlet Inventory

Read/Mutate: R = read-only, M = mutating, P = probe/test action.
Safety classes per [SAFETY-AND-LIVE-VALIDATION.md](SAFETY-AND-LIVE-VALIDATION.md):
RO = ReadOnlySystemManagement, TO = TestOwnedObjectMutation,
GS = GlobalSettingMutation, AA = AuthenticationOrAccessMutation,
AM = AlertingOrMonitoringMutation.

| Cmdlet | Area | Read/Mutate | Safety Class | REST Resource | ShouldProcess | Unit Tests | Integrity Tests | Live Tested | Notes |
|---|---|---|---|---|---:|---:|---:|---:|---|
| Get-DMLocalUser | Users | R | RO | `user`, `user/<id>` | — | Yes | Yes | Passed | 6 users |
| New-DMLocalUser | Users | M | AA/TO | `user` | Yes | Yes | No¹ | No | |
| Set-DMLocalUser | Users | M | AA | `user/<id>` | Yes | Yes | No¹ | No | |
| Remove-DMLocalUser | Users | M | AA/TO | `user/<id>` | Yes | Yes | No¹ | No | |
| Lock-DMLocalUser | Users | M | AA | `lockuser/<id>` | Yes | Yes | No¹ | No | |
| Unlock-DMLocalUser | Users | M | AA | `unlockuser/<id>` | Yes | Yes | No¹ | No | |
| Disable-DMLocalUserSession | Users | M | AA | `offline_user/<id>` | Yes | Yes | No¹ | No | |
| Reset-DMLocalUserPassword | Users | M | AA | `initialize_user_pwd/<id>` | Yes | Yes | No¹ | No | |
| Get-DMRole | Roles | R | RO | `role`, `role/<id>` | — | Yes | Yes | **Hangs (list)** / Passed (by-id) | Bug B-1 — **fixed** (list mode now unpaged) |
| Get-DMRolePermission | Roles | R | RO | `querying_permissions_available` | — | Yes | Yes | Passed | |
| New-DMRole | Roles | M | AA/TO | `role` | Yes | Yes | No¹ | No | |
| Set-DMRole | Roles | M | AA | `role/<id>` | Yes | Yes | No¹ | No | |
| Remove-DMRole | Roles | M | AA/TO | `role` | Yes | Yes | No¹ | No | |
| Get-DMSnmpConfig | SNMP | R | RO | `common/snmp_protocol` | — | Yes | Yes | Passed | |
| Set-DMSnmpConfig | SNMP | M | GS+AM | `common/snmp_protocol` | Yes | Yes | No¹ | No | |
| Get-DMSnmpSecurityPolicy | SNMP | R | RO | `common/snmp_security_policies` | — | Yes | Yes | Passed | |
| Set-DMSnmpSecurityPolicy | SNMP | M | GS+AM | `common/snmp_security_policies` | Yes | Yes | No¹ | No | |
| Set-DMSnmpCommunity | SNMP | M | GS+AM | `SNMP_COMMUNITY` | Yes | Yes | No¹ | No | SecureString ok |
| Get-DMSnmpTrapServer | SNMP | R | RO | `snmp_trap_addr` | — | Yes | Yes | Passed | 2 targets |
| New-DMSnmpTrapServer | SNMP | M | TO | `snmp_trap_addr` | Yes | Yes | No¹ | No | Best workflow candidate |
| Set-DMSnmpTrapServer | SNMP | M | TO | `snmp_trap_addr/<id>` | Yes | Yes | No¹ | No | |
| Remove-DMSnmpTrapServer | SNMP | M | TO | `snmp_trap_addr/<id>` | Yes | Yes | No¹ | No | |
| Test-DMSnmpTrapServer | SNMP | P | AM | `snmp_trap_addr/send_test_trapmsg` | No | Yes | No¹ | No | Sends real trap |
| Get-DMSnmpUsmUser | SNMP | R | RO | `snmp_usm` | — | Yes | Yes | Passed | |
| New-DMSnmpUsmUser | SNMP | M | TO | `snmp_usm` | Yes | Yes | No¹ | No | |
| Set-DMSnmpUsmUser | SNMP | M | TO | `snmp_usm` | Yes | Yes | No¹ | No | |
| Remove-DMSnmpUsmUser | SNMP | M | TO | `snmp_usm/<id>` | Yes | Yes | No¹ | No | |
| Get-DMSyslogNotification | Syslog | R | RO | `syslog` | — | Yes | Yes | Passed | |
| Set-DMSyslogNotification | Syslog | M | GS+AM | `syslog` | Yes | Yes | No¹ | No | |
| Add-DMSyslogServer | Syslog | M | TO (by address) | `syslog_addip` | Yes | Yes | No¹ | No | |
| Remove-DMSyslogServer | Syslog | M | TO (by address) | `syslog_removeip` | Yes | Yes | No¹ | No | |
| Get-DMNtpServer | NTP | R | RO | `ntp_client_config` | — | Yes | Yes | Passed | |
| Get-DMNtpStatus | NTP | R | RO | `ntp_client_config/get_ntp_status` | — | Yes | Yes | Passed | |
| Set-DMNtpServer | NTP | M | GS | `ntp_client_config` | Yes | Yes | No¹ | No | |
| Test-DMNtpServer | NTP | P | RO | `check_ntp_server_address_connective` | No | Yes | No¹ | No | Probe only |
| Get-DMTimeZone | Time | R | RO | `system_timezone` | — | Yes | Yes (IT-3 fixed) | Passed | |
| Set-DMTimeZone | Time | M | GS | `system_timezone` | Yes | Yes | No¹ | No | |
| Get-DMutcTime | Time | R | RO | `system_utc_time` | — | Yes | Yes (IT-3 fixed) | Passed | |
| Set-DMutcTime | Time | M | GS | `system_utc_time` | Yes | Yes | No¹ | No | |
| Get-DMdnsServer | DNS | R | RO | `dns_server` | — | Yes (UT-1 fixed) | Yes | Passed | Hashtable output |
| Set-DMdnsServer | DNS | M | GS | `dns_server` | Yes | Yes (UT-1 fixed) | Excluded (correct) | No | Harness-excluded |
| Get-DMSystem | System | R | RO | `system/` | — | Yes² | Yes | Passed | |
| Get-DMEquipmentStatus | System | R | RO | `server/status` | — | Yes | Yes (IT-3 fixed) | Passed | |
| Get-DMAlarm | Alarms | R | RO | `alarm/historyalarm?filter=…` | — | Yes² | Yes | Passed | 3 unrecovered, ~150 ms |

¹ No system-management mutation workflow exists (finding IT-1); these are
reported `SkippedUnsafe` in every run (IT-2 fixed — previously mutating
runs surfaced them as false `Blocked`).
² Covered by the older `Get-Storage`/hardware/network unit suites rather
than the system-configuration suites.

## Documentation Generated

- `docs/system-management/README.md`
- `docs/system-management/LOCAL-USERS-AND-ROLES.md`
- `docs/system-management/SNMP.md`
- `docs/system-management/NTP.md`
- `docs/system-management/SYSLOG.md`
- `docs/system-management/DNS.md`
- `docs/system-management/CERTIFICATES.md` (gap document)
- `docs/system-management/ALARMS-AND-EVENTS.md`
- `docs/system-management/SAFETY-AND-LIVE-VALIDATION.md`
- `docs/system-management/VALIDATION-REPORT.md` (this file)
- Updated: `docs/testing/INTEGRITY-TESTS.md` (new), `Tests/README.md`
  (status-meaning clarifications and system-management notes)

## Unit Test Coverage

Comprehensive for the domain: `Get-SystemConfiguration.Tests.ps1` (13
getters — REST routing, typed output, id-encoding, paging URL assertions)
and `Set-SystemConfiguration.Tests.ps1` (18 scenarios — CRUD for trap
servers/USM users/users/roles, NTP set + address validation, SNMP
config/security/community, syslog, time zone, UTC time, SecureString
acceptance, and a `-WhatIf` no-API-call guard). Gap: no unit tests for the
DNS pair (UT-1) — **fixed**: both suites now cover `Get-DMdnsServer`
(resource routing, hashtable output, JSON-string and array payloads) and
`Set-DMdnsServer` (PUT body, IPv4 validation, `-WhatIf` guard).

## Integrity Test Coverage

- 13/16 getters registered in `ReadValidation.ps1`; `Get-DMTimeZone`,
  `Get-DMutcTime`, `Get-DMEquipmentStatus` missing (IT-3) — **fixed**: all
  16 are now registered.
- No mutation workflow for the domain (IT-1); mutators misreported `Blocked`
  in mutating runs (IT-2) — empirically confirmed by the 2026-07-06 harness
  report (25 system mutators `Blocked`). **IT-2 fixed**: system mutators are
  now explicitly `SkippedUnsafe` in every run, with classification unit
  tests in `Tests/Unit/Private/ValidationReporting.Tests.ps1`. IT-1 open.
- `Set-DMdnsServer` correctly hard-excluded from live validation (IT-4).

## Live Commands Run

All read-only, against the lab array on 2026-07-07, authenticated with the
stored lab credential (never printed):

1. Getter sweep (script 1, killed after hanging in `Get-DMRole`; 13 getters
   before it were exercised but results discarded).
2. Getter sweep with per-step progress (script 2): 13 getters passed in
   37–209 ms each, then hung in `Get-DMRole` list mode; killed.
3. Raw REST paging probe: `role`, `role?range=[0-5]`, `role?range=[6-11]`,
   `role?range=[0-100]`, `user?range=[0-5]`, `snmp_trap_addr?range=[0-5]`
   (GET only) — identified the padding behavior; clean disconnect.
4. Remainder sweep (script 3): `Get-DMRole -Id 1`, `Get-DMRolePermission`,
   `Get-DMAlarm -AlarmStatus Unrecovered` — all passed; clean disconnect.

## Live Validation Results

- 15/16 getters **Passed** (every cmdlet exercised except `Get-DMRole` list
  mode). Typed outputs matched the expected `OceanStor*` classes.
- `Get-DMRole` list mode **hung** (bug B-1, below).
- Session hygiene: probes 3 and 4 disconnected cleanly. The two killed
  sweeps (1 and 2) could not run their `finally` disconnect, so two
  read-only REST sessions were orphaned on the array and will expire with
  the array's session timeout. No configuration was touched.

## Safety Findings

- **B-1 (`ImplementationBug`) — fixed**: `Get-DMRole` list mode looped forever on
  arrays whose `role` endpoint pads `range` responses (returns
  page-size copies of the first role instead of honoring the offset).
  Confirmed by raw probe: `role` → 15 distinct roles; `role?range=[0-100]`
  → 100 × role ID 1. Memory grows unboundedly (>2 GB observed). By-id path
  unaffected. Also poisons `Export-DMStorageToExcel`, which collects
  `Get-DMRole`. The 2026-07-06 harness report shows `Get-DMRole` passing
  (count 15) — that run either hit `Invoke-DMPagedRequest`'s unpaged
  fallback (array rejecting `range` with code 50331651 that day) or ran an
  older tree; today's padding behavior was consistent across all probes.
- **IT-2 (`SafetyGap`, reporting) — fixed**: mutating runs mislabeled all ~25
  system mutators as `Blocked` ("prerequisite resource was not created")
  when the truth was "no workflow exists / deliberately not run". They are
  now explicitly reported `SkippedUnsafe` in every run; `Blocked` is
  reserved for genuine same-run prerequisite failures.
- Mutator hygiene is otherwise good: `ShouldProcess` everywhere, a
  `-WhatIf` no-call unit guard, SecureString-friendly password parameters,
  and `Set-DMdnsServer` hard-excluded from the harness.

## Gaps Found

Known limitations and follow-up items: F-1 certificates, F-2 LDAP/AD,
F-3 alarm lifecycle/events, F-4 login security policy, F-5 email/SMTP
alerting, F-6..F-8 polish items; UT-1 DNS unit tests; IT-1..IT-3 integrity
harness gaps; B-1 role paging bug. Detailed internal gap-analysis notes
are archived outside the public documentation set.

## Recommended Corrections

Ordered: (0) fix B-1 — **done**; (1) reclassify system mutators as
`SkippedUnsafe` in mutating runs (IT-2) — **done**; (2) register the three
missing getters (IT-3) — **done**; (3) add a `SystemManagement` workflow for
test-owned SNMP trap server / USM user lifecycles, with user/role and syslog
sections default-off (IT-1) — **open**; (4) DNS unit tests (UT-1) —
**done**; then certificates (F-1) as the next feature branch.

## Follow-Up Implementation Plan

Suggested prompt/model split:

1. **Bug-fix + harness branch** (Sonnet-class model is sufficient; the
   changes are mechanical and the tests define success): B-1 + IT-2 + IT-3 +
   UT-1, with a regression unit test simulating the padded-page response.
2. **SystemManagement workflow branch** (Opus/Fable-class recommended;
   safety-sensitive design): IT-1, respecting the ownership-registry and
   cleanup-by-captured-ID conventions of the existing workflows.
3. **Certificate feature branch** (Opus/Fable-class; REST surface research
   against the Dorado 6.1.6 reference first): F-1 per
   [CERTIFICATES.md](CERTIFICATES.md).

## Verification Commands Run

- `git status` / `git diff --stat` / `git diff --check` (clean at start;
  docs-only additions at end).
- `Invoke-Pester` on the system-configuration unit suites (results in the
  final analysis summary).
- Read-only live scripts as listed under Live Commands Run. No mutating
  tests were executed; no test-owned objects were created, so no cleanup was
  required.
