# alpha-v1.0.0 Open Issues Phase 04 — Safety-Critical Deferred / Blocked Decisions

**Type:** Decision-only (+ Code only if an item is unblocked). **Live validation:** none in this phase
(any accepted item would be `SkippedUnsafe` in live runs). **Release-blocking:** NO.

## Purpose

Track the three safety-critical mutation decisions that are intentionally deferred or blocked, keep
their unblock criteria explicit, and prevent them from being silently re-planned or accidentally
implemented. Each carries high blast radius on shared/production storage or management state.

## Source TODOs / evidence

- `docs/system-management/TODO.md` High Priority #2 — Certificate management Stage B deferred.
- `Oceanstor_PSModule_TODO.md:14` + `docs/block-storage/TODO.md:19` — storage-pool Set/Rename
  **Deferred (Phase 08)**.
- `docs/system-management/TODO.md` Medium Priority "Alarm acknowledge/clear" decision (Phase 04).

## Current repository evidence

- **Certificates (Stage A shipped, Stage B deferred):** `Get-DMCertificate` read-only inventory
  exists (`OceanStorCertificate`). Stage B:
  - `Import-DMCertificate` — **blocked on vendor documentation** (6.1.6 documents activating an
    already-uploaded cert `PUT certificate/active`, not the upload step).
  - `Export-DMCertificate` — deferred (path-addressed download, unquantified private-key risk).
  - `Remove-DMCertificate` — endpoint documented (`DELETE om_msg_op_delete_certificate_info`) but
    deferred pending an approved lab-safe procedure.
- **Storage-pool Set/Rename — deferred/blocked:** `PUT storagepool/{id}` documented for **Dorado
  6.1.6 only**; module targets multiple generations (V3 + V6 LUN classes ship side by side);
  per-generation behavior cannot be confirmed without a lab array of each generation. High blast
  radius (shared infrastructure).
- **Alarm acknowledge — not planned (rejected):** 6.1.6 documents no acknowledge endpoint
  (`confirmTime` is read-only). **Alarm clear — future, blocked:** `DELETE alarm/currentalarm`
  is documented but destructive on real alarms, and the harness has no safe test-alarm generator.

## Scope

- Keep each decision, its blocker, and its unblock criteria current and single-sourced.
- If (and only if) an item becomes unblocked (new vendor docs / approved lab procedure / confirmed
  per-generation behavior), scope a minimal, `ConfirmImpact='High'`, mock-tested, `SkippedUnsafe`
  implementation — under a dedicated future phase, not silently here.

## Out of scope

- **Alarm acknowledge — rejected; do not re-plan** unless a new documented endpoint appears.
- Any live mutation of certificates, storage pools, or alarms.
- Speculative REST bodies against undocumented endpoints.

## Implementation tasks (decision-tracking; no code unless unblocked)

1. [x] Certificates: confirmed no new 6.1.6+ certificate-upload endpoint has appeared; Stage B stays
   deferred with the three per-cmdlet reasons intact.
2. [x] Storage pool: confirmed the multi-generation constraint still holds; `NAME`/`DESCRIPTION`/
   threshold-only scope recorded for any future accepted command.
3. [x] Alarm clear: kept deferred until a reliable test-alarm generator exists; alarm acknowledge
   stays rejected.

## Phase 04 review outcome (confirmed 2026-07-07)

Decision-only review complete. No item was unblocked; no code changed; no live validation was run.

- **Certificate Stage B — remains deferred/blocked.** `Import-DMCertificate` stays blocked on vendor
  documentation: the only documented file-upload interface in REST reference §4.3.5 is CRL import
  (`POST file/revokeCertificate?CMO_CERTIFICATE_TYPE=2`), **not** identity-certificate upload; the
  activated file (`PUT certificate/active`) still has no documented upload step. `Export-DMCertificate`
  stays deferred (path-addressed download, unquantified private-key risk). `Remove-DMCertificate` stays
  deferred (`DELETE om_msg_op_delete_certificate_info` documented, needs an approved lab-safe
  procedure). Single source of evidence: `.archived-commands/certificate-endpoint-research.md`; decision
  mirrored in `docs/system-management/TODO.md` (High Priority #2) and `docs/system-management/certificates.md`.
- **Storage-pool Set/Rename — remains deferred/blocked (Phase 08 backlog).** `PUT storagepool/{id}`
  is documented for Dorado 6.1.6 only; per-generation (V3/V6) behavior is unconfirmed and blast radius
  is high. Any future accepted scope is limited to `NAME` / `DESCRIPTION` / explicitly-documented
  threshold fields. Single source: `Oceanstor_PSModule_TODO.md` (Command Coverage Decisions);
  mirrored in `docs/block-storage/TODO.md` and `docs/block-storage/storage-pools.md`.
- **Alarm acknowledge — remains rejected / not planned.** No acknowledge endpoint documented;
  `confirmTime` is read-only. **Alarm clear — remains future / blocked** on a safe test-alarm
  generator (`DELETE alarm/currentalarm` is destructive on real alarms). Single source:
  `docs/system-management/TODO.md` (Medium Priority — alarm acknowledge/clear decision).

Unblock criteria (unchanged) for any future accepted item: documented endpoint behavior (or approved
lab-safe procedure / confirmed per-generation behavior), `SupportsShouldProcess`, `ConfirmImpact='High'`,
mock-only unit tests + `-WhatIf` no-API-call tests, permanent live-validation `SkippedUnsafe`, and an
explicit docs/release warning that pre-existing objects must never be touched.

## Files likely to inspect

- `docs/system-management/TODO.md`, `docs/system-management/certificates.md`,
  `.archived-commands/certificate-endpoint-research.md`
- `Oceanstor_PSModule_TODO.md`, `docs/block-storage/TODO.md`, `docs/block-storage/storage-pools.md`
- `OceanStor Dorado 6.1.6 REST Interface Reference.md` (targeted section lookups only)

## Files likely to modify

- The relevant `TODO.md` files (decision/blocker/unblock-criteria wording) only. No production code
  in this phase.

## Safety considerations

- No live array access. These are the module's highest-blast-radius surfaces (management certs,
  shared pools, alarm records) — the default posture is "do not implement without a reviewed,
  reversible, lab-safe procedure".
- Any future implementation: `SupportsShouldProcess`, `ConfirmImpact='High'`, unit tests with mocks
  only, permanent `SkippedUnsafe` in live validation, never touch pre-existing objects.

## Testing strategy

- Decision-only: no new tests unless an item is unblocked, in which case mock-only unit tests +
  `-WhatIf` no-API-call coverage are mandatory before any live consideration.

## Verification commands

```powershell
# targeted evidence checks only — do not dump the REST reference
Select-String -Path '.\OceanStor Dorado 6.1.6 REST Interface Reference.md' -Pattern 'certificate/active|delete_certificate_info' | Select-Object -First 5
```

## Dependencies

- Certificates: blocked on **vendor documentation**.
- Storage pool: blocked on **per-generation lab confirmation**.
- Alarm clear: blocked on a **safe test-alarm generator** (belongs to an alarm/event feature branch).

## Completion criteria

- [x] Each of the three items has a current, single-sourced decision with an explicit unblock trigger.
- [x] No item was implemented while still blocked; alarm acknowledge remains rejected.

**Status: COMPLETE (2026-07-07).** All three decisions reconfirmed current and single-sourced; nothing
unblocked; no production code changed; no live validation run.

## Risks / notes

- The main risk is scope-creep: implementing any of these without the stated safeguards could alter
  production storage access or management access. Keep them decision-only until genuinely unblocked.
