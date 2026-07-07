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

1. Certificates: confirm no new 6.1.6+ upload endpoint has appeared; keep Stage B deferred with the
   three per-cmdlet reasons intact.
2. Storage pool: confirm the multi-generation constraint still holds; keep the `NAME`/`DESCRIPTION`/
   threshold-only scope recorded for any future accepted command.
3. Alarm clear: keep deferred until a reliable test-alarm generator exists; alarm acknowledge stays
   rejected.

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

- Each of the three items has a current, single-sourced decision with an explicit unblock trigger.
- No item was implemented while still blocked; alarm acknowledge remains rejected.

## Risks / notes

- The main risk is scope-creep: implementing any of these without the stated safeguards could alter
  production storage access or management access. Keep them decision-only until genuinely unblocked.
