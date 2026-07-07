# alpha-v1.0.0 Open Issues Phase 03 — Safety-Critical Live Mutation Validation Runs

**Type:** Live-validation allowed (human-supervised, gated). **Release-blocking:** NO (evidence-gathering),
but required to promote the mutation workflows from "implemented, not exercised" to "validated".

## Status (2026-07-07)

Supervised session run against lab `10.10.10.24`. Read-only baseline `Blocked=0`,
post-run read-only `Blocked=0`, array returned to prior state, no leftover test objects,
no credential leakage.

- **SystemManagement (SNMP trap server, `AllowSnmpTrapServer` only) — DONE (exercised).**
  `New`/`Remove` validated (create + captured-ID cleanup); `Set`/`Test` failed with
  `API 50331651` → defect routed to `docs/system-management/TODO.md` High Priority #4
  (owning domain: Phase 04). Recorded in the integrity report Phase 03 log.
- **Failover-group — DEFERRED (own session).** One-gate-per-session discipline spent this
  session's gate on SystemManagement. Recorded in `docs/network/TODO.md`.
- **Replication/HyperMetro — DEFERRED.** Missing operator-supplied
  `RemoteDeviceId`/`RemoteLunId`/`DomainId`. Recorded in `docs/replication-hypermetro/TODO.md`.
- **`AllowSnmpUsmUser` / `AllowSyslogServer` / `AllowLocalUserLifecycle` — not run**
  (separate supervised single-gate sessions; local-user lifecycle stays off pending an
  explicit reviewed decision).

Remaining active work: schedule the failover-group session, the Replication/HyperMetro
session (needs lab IDs), and the remaining SystemManagement single-gate runs; fix defect
`50331651` in the owning SystemManagement phase.

## Purpose

Execute the already-implemented, config-gated mutation workflows against a lab array under
human supervision, and record the outcomes. Every workflow already follows the test-owned,
ID-tracked, cleanup-in-`finally` pattern; what remains is the supervised first run, which is
explicitly deferred because it requires an operator to supply lab-specific IDs and review the
intended config before enabling any gate.

## Source TODOs / evidence

- `docs/system-management/TODO.md` "Current Focus" #1 + High Priority #1 — SystemManagement
  workflow implemented (Phase 04), **first live validation run is a separately scheduled,
  human-supervised event** (runbook: `docs/testing/system-management-integrity-tests.md`).
- `docs/network/TODO.md` High Priority — "Human-supervised, gated live run of the failover-group
  workflow, then record the run outcome here."
- `docs/replication-hypermetro/TODO.md` High Priority — Replication/HyperMetro mutation workflows
  **"Deferred — requires human-supervised live run"**, blocked pending operator-supplied
  `RemoteDeviceId`/`RemoteLunId`/`DomainId` (runbook: `safety-and-live-validation.md#lab-pair-mutation-runbook`).

## Current repository evidence

- Workflows present: `Tests/Integration/Private/Workflows/SystemManagement.ps1`,
  `Tests/Integration/Private/Workflows/FailoverGroup.ps1`,
  and the Replication/HyperMetro workflows referenced by `Tests/Integration/Private/Workflows/`.
- All gates default **off** in `Tests/Integration/IntegrityValidationConfig.psd1`
  (`AllowSnmpTrapServer`, `AllowSnmpUsmUser`, `AllowSyslogServer`, `AllowLocalUserLifecycle`,
  `Replication.*`, `HyperMetro.*`, network VLAN/failover gates).
- Read-only evidence baseline: `Reports/getter-integrity-last-result.md` (2026-07-07,
  `Blocked=0`).

## Scope

- Plan and (with operator sign-off) run the gated mutation workflows one domain at a time,
  enabling only the specific gate under test, against test-owned objects only.
- Record each run's outcome back into the owning domain TODO and the integrity report.
- Populate operator-supplied lab IDs at run time only (never committed).

## Out of scope

- `AllowLocalUserLifecycle` (local role/user mutation) — security-sensitive, stays off unless a
  separate explicit reviewed decision enables it.
- Failover/switchover and NAS/vStore dual-array runs → Phase 06 (need dedicated flags / dual-array
  lab).
- Any change to workflow **code** (that would route back to the owning post-merge phase); this
  phase runs and records, it does not re-implement.

## Implementation tasks (per supervised session)

1. Operator reviews the target lab and the intended config; confirms it is a non-production array.
2. Enable exactly one gate in a local (uncommitted) config copy.
3. Run the harness read-only first to confirm `Blocked=0`, then with `-RunMutatingTests` for the
   enabled gate only.
4. Capture created-object IDs from the run log; confirm cleanup ran in `finally`.
5. Record pass/fail + any failed cleanup explicitly in the domain TODO and report artifact.

## Files likely to inspect

- `Tests/Integration/Invoke-GetterIntegrityValidation.ps1`,
  `Tests/Integration/IntegrityValidationConfig.psd1`
- `Tests/Integration/Private/Workflows/SystemManagement.ps1`, `FailoverGroup.ps1`,
  Replication/HyperMetro workflow files
- `docs/testing/system-management-integrity-tests.md`,
  `docs/replication-hypermetro/safety-and-live-validation.md`

## Files likely to modify

- Domain `TODO.md` files (record run outcomes) and the integrity report artifact only. **No code.**

## Safety considerations (STRICT — live array)

Live credential + target pattern (internal planning use only; never print credentials):

```powershell
$storageIP = '10.10.10.24'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
# lab array uses a self-signed cert:
#   -SkipCertificateCheck
```

- Query read-only freely; **create only test-owned objects** with a unique test prefix.
- Capture every created ID immediately; register cleanup immediately.
- Cleanup runs in `finally`; delete by captured ID only — **never broad-clean by name**.
- **Never mutate pre-existing objects.** Never touch existing users/roles/SNMP/syslog/certs or
  pre-existing DR pairs/domains.
- Report failed cleanup clearly and stop.
- Never print, echo, or log the credential object or any password.
- One gate per session; do not enable multiple mutation surfaces at once.

## Testing strategy

- Read-only pass must show `Blocked=0` before any mutation is enabled.
- Post-run read-only pass to confirm the array returned to its prior state (no leftover test
  objects).

## Verification commands

```powershell
# read-only baseline (no mutation)
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 -StorageIP $storageIP -Credential $cred -SkipCertificateCheck
# then, one enabled gate only, with -RunMutatingTests (operator-supervised)
```

## Dependencies

- Independent of Phase 01/02, but a clean unit gate (Phase 01) is recommended before promoting any
  workflow as "validated".
- Requires an operator, a non-production lab array, and lab-specific IDs.

## Completion criteria

- At least the SystemManagement and failover-group workflows exercised once under supervision, with
  outcomes recorded and cleanup confirmed.
- Replication/HyperMetro SAN pair workflows exercised when a remote-array pair and IDs are supplied.
- No pre-existing object mutated; no leftover test objects; no credential leakage.

## Risks / notes

- Highest operational risk phase — it is the only one that mutates a live array. Human supervision
  and one-gate-at-a-time discipline are mandatory.
- If the lab is unreachable from the working session, this phase is deferred, not failed — cite the
  existing read-only report as the current evidence.
