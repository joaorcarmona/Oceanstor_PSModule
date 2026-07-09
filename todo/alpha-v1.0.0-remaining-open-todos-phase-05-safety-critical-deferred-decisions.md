# alpha-v1.0.0 Remaining Open TODOs Phase 05 — Safety-Critical Deferred Decisions

**Type:** Decision-only (no code changes; each item stays deferred pending an external unblocker).
**Live validation allowed:** No.
**Release-blocking:** No — every item here was already independently deferred prior to this sweep;
none block the current alpha gate.

## Purpose

Consolidate the safety-critical items that are deliberately deferred **indefinitely** (not merely
scheduled, like Phase 04's sessions) because they lack a safe procedure, a documented REST
endpoint, or vendor-side documentation. This phase exists so these items are not lost track of or
mistakenly re-attempted without their blocker being resolved first.

## Source TODOs / evidence

- `docs/system-management/TODO.md` — Certificate Stage B: `Import-DMCertificate` blocked on vendor
  documentation (no upload endpoint documented); `Export-DMCertificate` deferred (unquantified
  private-key retrieval risk); `Remove-DMCertificate` deferred pending an approved lab-safe
  procedure. Also: LDAP/AD/Email/SMTP/local-login-password-policy — research-only, no dedicated
  endpoint found for password policy; research note exists at
  `docs/system-management/ldap-ad-smtp-alerting-research.md`. Alarm acknowledge — not planned, no
  endpoint documented. Alarm clear — `Clear-DMAlarm` cmdlet implemented (commit `f48845b`,
  `-WhatIf`/`ConfirmImpact = High`, clears by captured sequence only); **live validation** still
  deferred — no safe test-alarm generator exists.
- `docs/block-storage/TODO.md` — storage-pool `Set` (description/threshold/container) and
  create/delete/resize deferred, blocked on per-generation lab confirmation (V3 vs V6 LUN classes;
  only Dorado 6.1.6 reference available on-branch).
- `docs/network/TODO.md` — bond member add/remove after creation deferred permanently, no
  documented REST endpoint (verified 2026-07-07 against the Dorado 6.1.6 reference).
- `docs/replication-hypermetro/TODO.md` — DR batch operations deferred, no documented REST endpoint
  for per-object DR batch (`ADD_MIRROR`/`DEL_MIRROR`/`*/batch` not found in the 6.1.6 reference for
  `REPLICATIONPAIR` or `HyperMetroPair`).

## Current repository evidence

- No commits since these items were documented have added an `Import-DMCertificate`,
  `Export-DMCertificate`, `Remove-DMCertificate`, storage-pool `Set`/create/delete/resize, bond
  member add/remove, or DR batch cmdlet.
- **Exception (alarm clear):** the `Clear-DMAlarm` cmdlet *was* added (commit `f48845b`, exported in
  the module manifest) with `-WhatIf`/`ConfirmImpact = High` guards and clear-by-sequence semantics.
  Its implementation is not the deferred item — **live validation** of alarm clear stays deferred
  because no safe test-alarm generator exists to produce a test-owned alarm to clear.
- `docs/system-management/ldap-ad-smtp-alerting-research.md` exists (confirmed via directory
  listing) and remains research-only — no `Connect-DM*Ldap`/`Send-DMAlert`-style cmdlet exists in
  `POSH-Oceanstor/Public/`.

## Classification

All items: **Deferred indefinitely / decision-only**. None are release-blocking. Risk varies by
item (see table).

| Item | Blocker | Risk if implemented carelessly |
|---|---|---|
| `Import-DMCertificate` | No documented upload endpoint | High — could brick management-plane TLS |
| `Export-DMCertificate` | Unquantified private-key retrieval risk | High — key material exposure |
| `Remove-DMCertificate` | No approved lab-safe procedure | High — could break active TLS trust |
| Storage-pool Set/create/delete/resize | No per-generation (V3 vs V6) lab confirmation | High — capacity-affecting |
| Bond member add/remove | No documented REST endpoint | Medium — speculative body could misconfigure networking |
| DR batch operations | No documented REST endpoint | Medium — batch multiplies blast radius |
| Alarm acknowledge | No endpoint documented | Low — feature simply not possible today |
| Alarm clear (live validation) | Cmdlet implemented; no safe test-alarm generator to validate against | Medium — could suppress real alarms if exercised carelessly |
| LDAP/AD/Email/SMTP/password-policy | Research-only, no implementation phase yet | Low — nothing implemented to carry risk yet |

## Scope

- Document each item's current blocker clearly in one place.
- State explicitly what would need to change externally (vendor documentation, a lab-safe
  procedure, a test-alarm generator, etc.) before implementation could even be planned.

## Out of scope

- Implementing any of the above cmdlets or workflows.
- Speculatively guessing REST bodies for undocumented endpoints (explicitly rejected practice per
  existing domain TODOs).
- Live validation of any kind.

## Implementation tasks

None — this phase is a durable record of "do not implement until X changes," not an actionable
task list. Future re-evaluation triggers:

1. Certificate Stage B — re-open only when Huawei publishes/confirms an upload endpoint and a
   reviewed lab-safe removal procedure exists.
2. Storage-pool Set/create/delete/resize — re-open once a V3-generation lab (or vendor
   confirmation that Dorado 6.1.6 behavior applies uniformly) is available.
3. Bond member add/remove — re-open only with a confirmed REST reference section.
4. DR batch operations — re-open only with a confirmed REST reference section.
5. Alarm clear — cmdlet (`Clear-DMAlarm`) already implemented; only **live validation** stays
   deferred. Re-open the live exercise once a safe test-alarm generator (or equivalent test-owned
   alarm object) exists — exercise against a captured test-alarm sequence only, never pre-existing
   alarms.
6. Alarm acknowledge — no re-open trigger known; effectively rejected until Huawei documents an
   endpoint.
7. LDAP/AD/Email/SMTP/password-policy — re-open as a future feature branch (tracked in Phase 06)
   once there is appetite to scope an implementation phase; research note already captures the
   starting point.

## Files likely to inspect

- `docs/system-management/TODO.md`, `docs/system-management/ldap-ad-smtp-alerting-research.md`
- `docs/block-storage/TODO.md`
- `docs/network/TODO.md`
- `docs/replication-hypermetro/TODO.md`

## Files likely to modify

- None in this task. These domain TODO files already correctly describe each deferred item; no
  edit is needed unless wording needs to reference this consolidated phase file.

## Safety considerations

- These are exactly the class of item the task's hard safety rules warn against: do not mutate,
  create, modify, or delete storage/management objects the harness did not create in the same run,
  and do not speculatively implement undocumented endpoints. This phase's entire purpose is to keep
  that boundary explicit and visible.

## Testing strategy

- N/A — no code exists yet for any of these items.

## Verification commands

```powershell
git diff --check
git status --short
```

## Dependencies

- Each item depends on an external unblocker as described above; no dependency on other phases in
  this plan.

## Completion criteria

- This phase is "complete" as a documentation artifact once committed. Individual items are never
  marked complete here — they graduate out of this file into an implementation phase only once
  their blocker is externally resolved.

## Risks / notes

- The highest-risk items (certificates, storage-pool resize) should never be implemented from
  assumptions — always require a fresh, explicit vendor/lab confirmation before any future phase
  attempts them.
