# System Management — Safety and Live Validation

System-management cmdlets configure **global array behavior**: who can log
in, where alerts go, how time and names resolve. This page defines the safety
classification used across `docs/system-management/` and the rules for live
validation.

## Safety classes

| Class | Meaning | Live validation rule |
|---|---|---|
| `ReadOnlySystemManagement` | GET-only query | Safe to run live |
| `TestOwnedObjectMutation` | Creates/modifies/deletes a discrete object that the run itself created | Allowed only with registered cleanup by captured ID |
| `GlobalSettingMutation` | Rewrites a singleton global setting (DNS, NTP, time, syslog settings, SNMP config) | Do not run live without a dedicated lab-safe rollback plan |
| `AuthenticationOrAccessMutation` | Changes users, roles, passwords, sessions | Do not run live unless explicitly isolated and reversible |
| `AlertingOrMonitoringMutation` | Changes where/how alerts are delivered | Do not run live unless a test-owned target can be added/removed without touching production alerting |
| `CertificateMutation` | Imports/replaces/deletes certificates | Permanently `SkippedUnsafe` — never run live (no mutating cmdlets exist today; the rule stands even if they are built, because certificate changes can sever HTTPS management access) |
| `UnknownSystemMutation` | Effect not fully understood | Do not run live |
| `LocalFileOnly` | Writes only local files | Safe if the files are cleaned up |

## Per-cmdlet classification

| Cmdlet | Class |
|---|---|
| `Get-DMSystem`, `Get-DMEquipmentStatus`, `Get-DMAlarm` | ReadOnlySystemManagement |
| `Get-DMLocalUser`, `Get-DMRole`, `Get-DMRolePermission` | ReadOnlySystemManagement |
| `Get-DMSnmpConfig`, `Get-DMSnmpSecurityPolicy`, `Get-DMSnmpTrapServer`, `Get-DMSnmpUsmUser` | ReadOnlySystemManagement |
| `Get-DMSyslogNotification`, `Get-DMNtpServer`, `Get-DMNtpStatus`, `Get-DMTimeZone`, `Get-DMutcTime`, `Get-DMdnsServer` | ReadOnlySystemManagement |
| `Get-DMCertificate` | ReadOnlySystemManagement (registered in `ReadValidation.ps1`; the response schema contains no private-key material) |
| `Test-DMNtpServer` | ReadOnlySystemManagement (connectivity probe; PUT verb but no config change) |
| `Test-DMSnmpTrapServer` | AlertingOrMonitoringMutation (sends a real trap; point only at targets you own) |
| `New/Set/Remove-DMSnmpTrapServer` | TestOwnedObjectMutation (discrete object, ID-addressed) |
| `New/Set/Remove-DMSnmpUsmUser` | TestOwnedObjectMutation (discrete object, ID-addressed) |
| `Add/Remove-DMSyslogServer` | TestOwnedObjectMutation, **by address not ID** — extra care; see [syslog.md](syslog.md) |
| `Set-DMSyslogNotification` | GlobalSettingMutation + AlertingOrMonitoringMutation |
| `Set-DMSnmpConfig`, `Set-DMSnmpSecurityPolicy`, `Set-DMSnmpCommunity` | GlobalSettingMutation + AlertingOrMonitoringMutation |
| `Set-DMNtpServer`, `Set-DMTimeZone`, `Set-DMutcTime` | GlobalSettingMutation |
| `Set-DMdnsServer` | GlobalSettingMutation (hard-excluded from the harness) |
| `New/Set/Remove-DMLocalUser`, `Lock/Unlock-DMLocalUser`, `Disable-DMLocalUserSession`, `Reset-DMLocalUserPassword` | AuthenticationOrAccessMutation (New/Remove of a *test-created* user may be treated as TestOwnedObjectMutation) |
| `New/Set/Remove-DMRole` | AuthenticationOrAccessMutation (same test-owned caveat) |

## Live-validation rules

1. **Read anything.** All getters above are safe live.
2. **Mutate only what this run created.** Register every created object
   immediately (kind, ID, name, creation time, cleanup command), clean up in
   `finally`, and delete by captured ID — never by name match, never broadly.
3. **Never touch pre-existing configuration**: users, roles, SNMP targets,
   communities/USM users, syslog servers, NTP servers, DNS, alerting
   settings, security policy, certificates, global settings.
4. **Global settings are not live-testable.** There is no test-owned variant
   of DNS/NTP/time/SNMP-config/syslog-settings. Validate these with unit
   tests and `-WhatIf`; live changes belong in a dedicated lab with an
   explicit rollback plan.
5. **Do not disable services**: SNMP, syslog, NTP, authentication, alerting.
6. **Cleanup order matters**: test users must be removed before their test
   role (role deletion can be rejected while assigned).
7. If cleanup fails, report the object kind, ID, name, and the exact manual
   cleanup command; do not retry with broader matching.

## How the integrity harness applies these rules today

- Read-only runs (`Invoke-GetterIntegrityValidation.ps1` without
  `-RunMutatingTests`) exercise the system-management getters registered in
  `ReadValidation.ps1` and mark all mutators `NotRequested` or
  `SkippedUnsafe`.
- `Set-DMdnsServer` is permanently excluded via the harness
  `excludedCommands` list — the reference pattern for global-setting
  mutators.
- The config-gated **`SystemManagement` workflow**
  (`Tests/Integration/Private/Workflows/SystemManagement.ps1`) covers the
  discrete, test-ownable objects. It is **disabled by default** and each
  section has its own gate in `IntegrityValidationConfig.psd1`:

  | Gate | Lifecycle | Default |
  |---|---|---|
  | `SystemManagement.Enabled` | Master gate — nothing runs without it | `$false` |
  | `SystemManagement.AllowSnmpTrapServer` | SNMP trap server create → update → test → remove by captured ID | `$false` |
  | `SystemManagement.AllowSnmpUsmUser` | SNMP USM user create → update → remove (run-unique name, generated throwaway passwords) | `$false` |
  | `SystemManagement.AllowSyslogServer` | Syslog server add → remove by the exact recorded address | `$false` |
  | `SystemManagement.AllowLocalUserLifecycle` | Local role + local user lifecycle (security-sensitive) | `$false` |

  `-RunMutatingTests` alone never executes any of these sections; the
  master gate **and** the relevant sub-gate must both be enabled. Every
  sub-workflow refuses to run if its test address/name already exists on
  the array (it never claims a pre-existing object as test-owned), registers
  cleanup immediately after create, and removes only by captured ID or the
  exact recorded address. A security-policy rejection of the generated USM
  or local user is reported (failed create + `Blocked` dependents) and does
  not abort the run; nothing is left behind in that case. Anything that
  could not be cleaned up is listed under `RemainingTestOwnedResources` in
  the validation report.
- Global settings (NTP, DNS, time, SNMP config/security/community, syslog
  notification settings) and actions against pre-existing users
  (lock/unlock/password reset/session termination) remain permanently
  `SkippedUnsafe` — no test-owned variant exists for them.

## Status vocabulary (integrity reports)

| Status | Meaning |
|---|---|
| `Passed` | Ran and returned the expected shape |
| `NoData` | Ran, no matching objects on the array |
| `NotRequested` | Mutation mode not requested (`-RunMutatingTests` absent) |
| `NotConfigured` | The relevant workflow/identity is disabled in `IntegrityValidationConfig.psd1` |
| `SkippedUnsafe` | Deliberately never run live (unsafe by policy) |
| `Blocked` | A prerequisite test-owned resource failed to create |
| `NotExecuted` | Fell through — no workflow represented the command in this run |
| `Failed` / `UnexpectedType` | Ran and failed / returned the wrong type |

Interpretation note: *global* system-management mutators (NTP, time, SNMP
config/security/community, syslog notification settings, lock/unlock/
password-reset actions against existing users) are reported as
`SkippedUnsafe` in every run — the harness deliberately never exercises
them. The discrete lifecycles (SNMP trap server, SNMP USM user, syslog
server, local role/user) are covered by the `SystemManagement` workflow and
report `NotRequested` (read-only run) or `NotConfigured` (mutating run with
the gate off) until their gates are explicitly enabled. `Blocked` is
reserved for commands whose test-owned prerequisite genuinely failed to
create in the same mutating run.
