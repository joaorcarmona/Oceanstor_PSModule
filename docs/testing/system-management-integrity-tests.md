# Integrity Tests — System Management Coverage

Companion to `Tests/README.md` (runner usage, status meanings) and
`docs/system-management/safety-and-live-validation.md` (safety
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

## The SystemManagement mutation workflow (Phase 04)

`Tests/Integration/Private/Workflows/SystemManagement.ps1` implements the
opt-in, test-owned system-management lifecycles. **Everything is disabled by
default**: `-RunMutatingTests` alone never runs any of it; the
`SystemManagement.Enabled` master gate *and* the relevant sub-gate in
`Tests/Integration/IntegrityValidationConfig.psd1` must both be `$true`.

| Sub-workflow | Gate | Lifecycle | Cleanup identity |
|---|---|---|---|
| SNMP trap server | `AllowSnmpTrapServer` | create → update (port) → send one test trap → remove | Captured trap server ID |
| SNMP USM user | `AllowSnmpUsmUser` | create → update (user level) → remove | Run-unique user name (the REST ID) |
| Syslog server | `AllowSyslogServer` | add → remove | Exact recorded address |
| Local role + user | `AllowLocalUserLifecycle` (security-sensitive) | role create → role update → user create → user update → user remove → role remove | Captured role/user IDs; user removed before role |

Shared safety behavior:

- Test identities are run-unique (`NamePrefix` + run timestamp) or the
  dedicated `SystemManagement.*Address` config values; if the address/name
  already exists on the array the step **fails loudly and refuses** to claim
  the object — pre-existing SNMP, syslog, user, and role configuration is
  never modified, matched by pattern, or cleaned.
- Object identity is captured immediately after create, cleanup is
  registered immediately, and cleanup runs through the registered-cleanup
  mechanism at end of run (step failures are caught and recorded, so cleanup
  still executes). Removal is only ever by captured ID or exact recorded
  address.
- USM/local-user passwords are generated per run, never persisted, and the
  mutation request trace redacts password fields.
- If the array security policy rejects the generated USM or local user, the
  create step reports the array's message and the dependent steps show
  `Blocked`; this is an accepted, non-fatal outcome and nothing is left
  behind. Any resource that could not be removed is listed under
  `RemainingTestOwnedResources` in the report, with a manual cleanup hint in
  the step reason.

## What is skipped, and how to read the statuses

- **Every run** (read-only and mutating): the *global* system-management
  mutators (NTP, time, SNMP config/security/community, syslog notification
  settings, and lock/unlock/password-reset actions against existing users)
  are listed explicitly as `SkippedUnsafe` — no test-owned variant exists
  for them. They no longer fall through to the coverage fallback, so
  mutating runs no longer mislabel them as false `Blocked` (finding IT-2,
  fixed).
- The SystemManagement workflow commands report `NotRequested` in read-only
  runs and `NotConfigured` in mutating runs while their gates are off.
- `Blocked` is reserved for commands whose test-owned prerequisite
  genuinely failed to create during the same mutating run (including a
  security-policy rejection of a generated test user).
- `Set-DMdnsServer` is permanently excluded (`excludedCommands` in
  `MutationValidation.ps1`) and never appears — the intended pattern for
  global-setting mutators.

Interpretation cheat-sheet for the domain:

| You see | It means | Action |
|---|---|---|
| Getter `Passed`/`NoData` | Live read validated | None |
| Workflow mutator `NotRequested` | Read-only run | None |
| Workflow mutator `NotConfigured` | Mutating run, SystemManagement gate off | Enable the gate only for a reviewed lab run |
| Mutator `SkippedUnsafe` | Deliberately never run live (no safe workflow) | None |
| Mutator `Blocked` (mutating run) | A test-owned prerequisite really failed (or policy rejected the generated test user) | Read the create step's reason |
| `RemainingTestOwnedResources` non-empty | Cleanup could not remove something | Remove it manually by the listed identity |
| Getter absent from report | Not registered in `ReadValidation.ps1` | Register it |

## Runbook: future human-supervised gated lab run

The first live execution of the SystemManagement workflow is a separately
scheduled, human-supervised event — never part of routine validation.

Prerequisites:

- Lab array only, with a maintenance-window agreement; the lab array uses a
  self-signed certificate, so the runner needs `-SkipCertificateCheck`.
- Confirm the configured `SnmpTrapServerAddress` and `SyslogServerAddress`
  are addresses you own and are **not** already configured on the array
  (the workflow re-checks and refuses, but verify first).
- Read-only baseline first: run the harness without `-RunMutatingTests` and
  keep the report.
- Review `IntegrityValidationConfig.psd1`: enable `SystemManagement.Enabled`
  plus only the sub-gates agreed for the run. Leave
  `AllowLocalUserLifecycle = $false` unless the security review explicitly
  approved it for this run.

Execution (public placeholder form — substitute your lab values):

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 -Hostname $storageIP `
    -Credential $cred -SkipCertificateCheck -RunMutatingTests -ShowTestExecution
```

Expected report outcomes:

- Enabled sub-workflow steps: `Passed` (create/update/remove and
  `Verify:*:ReadBack` rows), or a reported non-fatal `Failed` create +
  `Blocked` dependents if the array security policy rejects a generated
  test user.
- Disabled sub-workflows: `NotConfigured`.
- `RemainingTestOwnedResources`: **must be empty**. If not, remove the
  listed objects manually by the captured identity (e.g.
  `Remove-DMSnmpTrapServer -Id <id>`) and investigate before re-running.
- Global mutators: still `SkippedUnsafe` — the workflow never touches them.

Rollback expectations: the workflow is self-cleaning (LIFO registered
cleanup, users before roles). No pre-existing configuration is modified, so
there is nothing to roll back beyond the test-owned objects themselves.
After the run, disable all `SystemManagement` gates again and re-run the
read-only baseline to confirm the array configuration is unchanged.

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
4. ~~Add an opt-in `SystemManagement` workflow for SNMP trap server + USM
   user lifecycles; keep user/role and syslog sections default-off (IT-1)~~ —
   **implemented** (Phase 04): all four lifecycles exist behind individual
   config gates, everything default-off; first live run pending per the
   runbook above.

Implementation validation notes were used to produce the system-management
TODO (`docs/system-management/TODO.md`). The validation report itself is not
part of the public documentation set.
