# alpha-v1.0.0 Remaining Open TODOs Phase 01 — Release-Readiness Refresh and SNMP Trap Update Defect

> **STATUS: DONE (2026-07-09).**
> - Docs refresh — **complete**: `todo/release-readiness-go-no-go.md` now headlines
>   `Current hard-gate decision: GO (Phase 01, 2026-07-07)` with the original NO-GO evidence
>   preserved as a dated historical section; §10 Recommendation marked SUPERSEDED.
> - Dangling refs — **complete**: no `post-merge-phase-*` references remain in
>   `Oceanstor_PSModule_TODO.md` (network hardening → `docs/network/TODO.md` "Recently
>   Completed"; coverage decisions → `remaining-open-todos-phase-05`).
> - SNMP `50331651` defect — **root cause found from the in-repo REST reference and fixed in
>   code + unit tests** (ahead of the original "later session" plan, since static evidence was
>   conclusive): `Set-DMSnmpTrapServer` now sends `ID` in the modify body; `Test-DMSnmpTrapServer`
>   now always sends the Mandatory `CMO_TRAP_SERVER_TYPE`/`CMO_TRAP_VERSION`. **Live re-confirm
>   still owed** — tracked in `docs/system-management/TODO.md` item 4 and Phase 04.

**Type:** Docs-only (status refresh) + Code+Tests (one defect fix, implemented in a later phase).
**Live validation allowed:** No (this phase is planning/refresh only; the defect fix itself will
need a live re-check in a future supervised session, out of scope here).
**Release-blocking:** Partly — the go/no-go document's own status header is stale and must not be
read as the current release decision; the SNMP defect is a real bug but does not block the
existing alpha gate (create/remove already validated).

## Purpose

Two small but important loose ends surfaced by this sweep:

1. `todo/release-readiness-go-no-go.md` still headlines **Decision: NO-GO** from the original
   2026-07-07 evidence run, even though its own inline "Phase 01 update" note (added later in the
   same file) says the hard gate is now **GO** (0 analyzer errors, 1232/1232 tests passing). A
   reader skimming only the top of the file gets the wrong answer.
2. `docs/system-management/TODO.md` records an unresolved API defect
   (`Set-DMSnmpTrapServer` / `Test-DMSnmpTrapServer` reject their payload with `OceanStor API
   error 50331651`) that has not yet been investigated or fixed in cmdlet code.

## Source TODOs / evidence

- `todo/release-readiness-go-no-go.md` lines 1–33 (stale `NO-GO` header vs. the Phase 01 update
  note immediately below it) and lines 280–294 (`## 10. Recommendation`, written against the
  original FAIL evidence, not the current state).
- `docs/system-management/TODO.md` "### 4. `Set-DMSnmpTrapServer` / `Test-DMSnmpTrapServer` reject
  update payload — API error 50331651 (found Phase 03, 2026-07-07)".
- `docs/system-management/TODO.md` "### 3. SNMP USM user credential-parameter analyzer finding —
  RESOLVED (Phase 01, 2026-07-07)" — confirms the analyzer-error half of the gate is closed.
- `Oceanstor_PSModule_TODO.md` lines 17 and 19 reference
  `todo/alpha-v1.0.0-post-merge-phase-06-network-hardening-and-workflows.md` and
  `todo/alpha-v1.0.0-post-merge-phase-08-block-file-nas-coverage-decisions.md` — **neither file
  exists** under that name in `todo/` (the phase-file naming scheme was later renamed to
  `alpha-v1.0.0-open-issues-phase-*`). These are dangling cross-references, not open work items.

## Current repository evidence

- `git grep` / `Get-ChildItem` on `todo/` confirms only `alpha-v1.0.0-open-issues-phase-01..08`,
  `release-readiness-go-no-go.md`, and `followup-name-loopvar-collision-audit.md` exist — no
  `post-merge-phase-*` files.
- `todo/alpha-v1.0.0-open-issues-phase-01-release-blockers-gate.md` header confirms
  `> STATUS: COMPLETE (2026-07-07)` for the analyzer/test gate fix.
- No commit since 2026-07-07 has touched `Set-DMSnmpTrapServer.ps1` or `Test-DMSnmpTrapServer.ps1`
  (recent commits are alarm history, DR carry-over, and Phase 08 docs polish) — the defect is
  still unfixed in the working tree.

## Classification

| Item | Classification | Risk |
|---|---|---|
| Go/no-go doc stale header | Stale / needs refresh (docs-only) | Low |
| Dangling `post-merge-phase-06/08` references in `Oceanstor_PSModule_TODO.md` | Stale / remove (docs-only) | Low |
| `Set-DMSnmpTrapServer`/`Test-DMSnmpTrapServer` defect 50331651 | Open (code defect, needs investigation) | Medium — affects a shipped mutator's update/test path |

## Scope

- Docs-only: rewrite the go/no-go document's top summary (or add a clearly dated superseding
  section) so the headline decision matches the Phase 01 update note, without deleting the
  original evidence (it has historical value).
- Docs-only: fix or remove the two dangling `post-merge-phase-06`/`post-merge-phase-08` links in
  `Oceanstor_PSModule_TODO.md`, pointing instead at the current `open-issues-phase-05`/`-07`/`-08`
  files that carry the equivalent content, or removing the pointer if the item is fully resolved.
- Planning only for the SNMP defect: this phase file records the investigation plan; the actual
  code fix is implemented in a later, dedicated session (not this planning task).

## Out of scope

- Do not modify `Set-DMSnmpTrapServer.ps1` / `Test-DMSnmpTrapServer.ps1` in this task.
- Do not re-run the full unit/analyzer gate as part of this planning sweep (no code changed here).
- Do not connect to any array to reproduce error `50331651`.
- Do not re-open Phase 01's analyzer/test work — it is complete; only the document's presentation
  is stale.

## Implementation tasks

For the eventual (separate) execution of this phase:

1. Update `todo/release-readiness-go-no-go.md`'s title/decision line to reflect the current state
   (`GO on the hard gate as of 2026-07-07 Phase 01`; signing/publishing and live-mutation items
   remain separately tracked in Phase 02 / Phase 04 of this plan). Keep the original evidence
   intact underneath as a dated historical record.
2. Fix the two dangling links in `Oceanstor_PSModule_TODO.md` (lines 17, 19).
3. Investigate the `50331651` defect: compare the `Set-DMSnmpTrapServer` / `Test-DMSnmpTrapServer`
   request-body construction against the 6.1.x SNMP trap-server REST reference used elsewhere in
   the module (`ConvertTo-DMRequestBody` usage, field names/casing, optional-vs-required fields).
   Identify the likely mismatched field(s) without live access first; confirm with a supervised
   live re-run afterward (tracked in Phase 04 of this plan, not here).
4. Add/adjust a unit test once the fix is identified, mirroring the existing mock-based pattern
   for other `Set-DM*`/`Test-DM*` cmdlets.

## Files likely to inspect

- `todo/release-readiness-go-no-go.md`
- `Oceanstor_PSModule_TODO.md`
- `docs/system-management/TODO.md`
- `POSH-Oceanstor/Public/Set-DMSnmpTrapServer.ps1`
- `POSH-Oceanstor/Public/Test-DMSnmpTrapServer.ps1`
- `POSH-Oceanstor/Public/New-DMSnmpTrapServer.ps1` (known-good sibling for comparison)
- `Tests/Unit/Public/*SnmpTrapServer*.Tests.ps1`

## Files likely to modify

- `todo/release-readiness-go-no-go.md` (docs-only, this phase)
- `Oceanstor_PSModule_TODO.md` (docs-only, this phase)
- `POSH-Oceanstor/Public/Set-DMSnmpTrapServer.ps1`, `Test-DMSnmpTrapServer.ps1`, and their test
  files (code+tests, a later execution session — not this planning task)

## Safety considerations

- The defect investigation itself is read-only analysis against documentation and existing code;
  no live array access is needed to form a hypothesis.
- Confirming the fix requires a human-supervised live SNMP-trap-server session under the existing
  `SystemManagement.Enabled` + `AllowSnmpTrapServer` gate — reuse the same test-owned object /
  captured-ID cleanup pattern already implemented in
  `Tests/Integration/Private/Workflows/SystemManagement.ps1`. Do not widen the gate surface.

## Testing strategy

- Docs-only edits require no test run.
- The SNMP defect fix (when implemented) needs a new/updated unit test asserting the corrected
  request body, plus a supervised live re-run of `Set-DMSnmpTrapServer`/`Test-DMSnmpTrapServer`
  against the lab array to confirm `50331651` no longer occurs.

## Verification commands

```powershell
git diff --check
git status --short
Select-String -Path todo/release-readiness-go-no-go.md -Pattern 'NO-GO|GO on the hard gate'
Select-String -Path Oceanstor_PSModule_TODO.md -Pattern 'post-merge-phase'
```

## Dependencies

- None for the docs refresh.
- The SNMP defect fix depends on eventual access to a lab array for confirmation (see Phase 04).

## Completion criteria

- Docs-only sub-items: go/no-go doc headline matches its own evidence; no dangling
  `post-merge-phase-*` references remain in `Oceanstor_PSModule_TODO.md`. These can be marked
  complete and cleared from the active plan once committed.
- SNMP defect: stays open until a code fix lands and is live-verified; do not mark complete from
  this planning phase.

## Risks / notes

- Low risk throughout — no production behavior changes in this planning phase itself.
- The SNMP defect is scoped to update/test only; create/remove already work, so this is not a
  hard blocker for the existing alpha release decision, but should not be left unowned.
