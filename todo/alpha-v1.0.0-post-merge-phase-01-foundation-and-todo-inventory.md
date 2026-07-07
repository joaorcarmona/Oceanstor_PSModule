# alpha-v1.0.0 Post-Merge Phase 01 — Foundation and TODO Inventory

## Purpose

Establish a single, deduplicated, code-verified inventory of all remaining work on the
published `alpha-v1.0.0` branch (module v0.9.5, 299 exported commands), and reconcile the
domain TODO files with what the code actually contains today, so every later phase starts
from accurate sources instead of stale roadmap text.

## Source TODOs / evidence

- `Oceanstor_PSModule_TODO.md` — root backlog: 5 open "Command Coverage Decisions"
  checkboxes, "Develop Robust API Mocking", "Automate Release Pipeline to PowerShell
  Gallery". Large Completed/Rejected history that later phases must not re-plan.
- `docs/system-management/TODO.md` — mutation workflow, certificates, LDAP/AD, alerting,
  alarm filtering, syslog params, DNS typed output.
- `docs/network/TODO.md` — WhatIf tests, failover-group member getter, live workflow,
  server-side filters, `Set-DMLif -Id`, future route/iSCSI/NVMe branches.
- `docs/replication-hypermetro/TODO.md` — DR getters in read validation, lab mutation run,
  WhatIf coverage across 51 mutators, batch ops, quorum inventory cmdlet.
- `docs/testing/performance-integrity-tests.md` (§ "Why performance commands may appear
  as `NotRequested` or previously `Blocked`") — reporting-side fix "proposed but not yet
  implemented".
- `docs/testing/integrity-tests.md` (note on `Blocked` vs `NotRequested`).

Deduplication decision:
The root TODO's fifth coverage decision ("whether network objects … should remain
read-only or gain supported mutation commands") is **already answered** by the merged
network branch (bond/VLAN/LIF/failover-group lifecycles shipped). Phase 01 closes that
checkbox as resolved-by-code rather than carrying it into Phase 08.

## Scope

- [Docs-only] Verify every open TODO bullet in the three domain TODO files and the root
  TODO against current code (this analysis already spot-checked the high-priority ones;
  finish the sweep for medium/low bullets).
- [Docs-only] Mark or move bullets that are demonstrably done (e.g. items that shipped in
  the merges) into each TODO's "Recently Completed" section.
- [Docs-only] Close the resolved network-mutation coverage decision in
  `Oceanstor_PSModule_TODO.md` with a one-line pointer to `docs/network/`.
- [Docs-only] Record cross-domain dedup decisions (listed per phase in these files) inside
  each TODO file where an item is intentionally tracked elsewhere.
- [Docs-only] Confirmed-no-work items to record and not re-plan:
  - Manifest/export consistency: `FunctionsToExport` (299) exactly matches
    `POSH-Oceanstor/Public/*.ps1` (299); `ModuleInventory.Tests.ps1` already enforces it.
  - Performance cmdlet machinery: verified healthy in the 2026-07-06 follow-up run with
    `-IncludePerformance`; only the reporting label fix (Phase 02) remains.

## Out of scope

- Any code change. Any new cmdlet. Any harness change (Phase 02+).
- Rewriting TODO files wholesale — only accuracy corrections.

## Implementation tasks

- [Docs-only] Sweep each open TODO bullet; annotate status: `open`, `done-in-merge`,
  `superseded`, or `needs-decision`.
- [Docs-only] Update the three domain TODO files' Recently Completed / High Priority
  sections to match code reality.
- [Docs-only] Close the network coverage-decision checkbox in `Oceanstor_PSModule_TODO.md`.
- [Docs-only] Add explicit cross-references where one item is tracked in another domain
  (e.g. the reporting fix lives in testing docs but affects performance and
  system-management reporting).

## Files likely to inspect

- `Oceanstor_PSModule_TODO.md`, all three `docs/*/TODO.md`
- `docs/testing/*.md`, `POSH-Oceanstor/Public/` (existence checks only)
- `Tests/Integration/Private/ReadValidation.ps1`, `Tests/Integration/Private/Reporting.ps1`

## Files likely to modify

- `Oceanstor_PSModule_TODO.md`
- `docs/system-management/TODO.md`, `docs/network/TODO.md`,
  `docs/replication-hypermetro/TODO.md`

## Safety considerations

- No live array access. Read-only repository work.
- Do not delete TODO history; move items between sections instead.

## Testing strategy

- Docs-only: markdown link check by hand; no unit tests required.

## Verification commands

```powershell
git diff --check
git status
git diff --stat
```

## Dependencies

- None. This phase gates all others.

## Completion criteria

- Every open bullet across the four TODO files carries a verified status.
- No TODO bullet claims work that the code already contains.
- Cross-domain dedup notes exist wherever two files describe one work item.

## Risks / notes

- `.archived-commands/` is gitignored — these phase files stay local. If team-shared
  planning is desired, that is a deliberate later decision, not part of this phase.
- Keep `README.md`/`TODO.md` uppercase convention; all other docs lowercase.
