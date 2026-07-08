# alpha-v1.0.0 Remaining Open TODOs Phase 07 — Documentation Polish Backlog

**Type:** Docs-only.
**Live validation allowed:** No.
**Release-blocking:** No.

## Purpose

Consolidate the remaining Low Priority / Polish documentation items across all seven domain
`TODO.md` files, plus fold in the stale cross-reference cleanup identified during this sweep, into
one docs-only backlog.

## Source TODOs / evidence

- `docs/network/TODO.md` "## Low Priority / Polish": friendly-name parameters instead of raw enums
  (code enhancement, not implemented — already deferred with a documentation note in
  `bond-ports.md`/`vlans.md`); decode more display fields on `OceanStorvLan`/`OceanStorPortBond`
  (code enhancement, not implemented — already noted in `bond-ports.md`, `vlans.md`,
  `logical-ports.md`).
- `docs/network/TODO.md` "## Future Feature Branches" header: stale reference to
  `todo/alpha-v1.0.0-post-merge-phase-06-network-hardening-and-workflows.md`, which does not exist
  under that name (renamed to the `open-issues-phase-*` family). Needs correcting to avoid
  misdirecting readers.
- `docs/replication-hypermetro/TODO.md` "## Documentation": pending live evidence from Phase 03/06
  supervised runs (cannot be resolved until Phase 04 of this plan's scheduled sessions actually
  run — tracked there, restated here only as a docs-freshness dependency).
- `docs/qos/TODO.md` "## Low Priority / Polish": compact reporting examples for policy inventory;
  small glossary for SmartQoS API concepts.
- `docs/block-storage/TODO.md`, `docs/file-storage/TODO.md`, `docs/snapshots/TODO.md`: each domain's
  remaining Low Priority / Polish items (deeper examples, diagrams, inventory views, troubleshooting
  pages) largely addressed by the existing Phase 08 docs-polish pass, per commit
  `c79921a "Phase 08: polish block/network/QoS docs; sanitize lab IP; keep DR items gated"` — this
  phase captures anything not yet covered rather than re-doing completed work.
- `Oceanstor_PSModule_TODO.md` lines 17, 19: dangling `post-merge-phase-06`/`post-merge-phase-08`
  cross-references (same finding as Phase 01 of this plan; the actual fix is scoped to Phase 01,
  restated here only for completeness of the docs-hygiene picture).

## Current repository evidence

- `git log` confirms commit `c79921a` already performed a "Phase 08" docs polish pass covering
  block/network/QoS docs and sanitizing a lab IP — most Low Priority items across those three
  domains are likely already resolved by that commit. This phase should re-check each domain's
  "Low Priority / Polish" section against current doc content before assuming an item is still
  open, rather than duplicating already-completed work.
- The network TODO's stale `post-merge-phase-06` reference (inside its own "Future Feature
  Branches" header, not just in `Oceanstor_PSModule_TODO.md`) was not touched by commit `c79921a` —
  still present as of this sweep.

## Classification

Docs-only, low risk, not release-blocking.

## Scope

- Fix the stale `post-merge-phase-06` reference inside `docs/network/TODO.md`'s own "Future Feature
  Branches" section header (separate occurrence from the one in `Oceanstor_PSModule_TODO.md`
  handled in Phase 01).
- Re-verify which Low Priority / Polish items across all domains remain genuinely open after the
  `c79921a` Phase 08 pass, and address only what is still outstanding.
- Add the QoS glossary and compact reporting examples if not already covered.
- Add the network friendly-name-alias and display-field-decoding notes only if not already present
  (evidence suggests `bond-ports.md`, `vlans.md`, and `logical-ports.md` already carry these notes
  from Phase 08 — confirm before duplicating).

## Out of scope

- Any code enhancement implied by a docs item (e.g., friendly-name enum aliases are a code change,
  not a docs change — that stays in Phase 06's backlog, not here).
- Re-writing already-completed Phase 08 docs content.
- Publishing any raw validation/gap-analysis file under `docs/` (must stay under
  `.archived-commands/`, `archived-commands/`, or `todo/` per project convention).
- Introducing the lab IP `10.10.10.24` into any public doc — public examples must use
  `$storageIP = 'StorageIP'` only.

## Implementation tasks

1. Fix `docs/network/TODO.md`'s "Future Feature Branches" section header to reference the correct
   existing file (or drop the specific filename reference and just say "not yet scheduled").
2. Diff each domain's current "Low Priority / Polish" section against its doc pages to confirm
   which items commit `c79921a` already resolved; strike those from the active list.
3. Add the QoS SmartQoS glossary and compact policy-inventory reporting examples if still missing.
4. Confirm the network friendly-name/display-field notes already exist in `bond-ports.md`,
   `vlans.md`, `logical-ports.md` (per Phase 08 evidence) — if so, remove the now-redundant
   "Low Priority / Polish" line items from `docs/network/TODO.md` since the polish is done, only the
   underlying code enhancement remains (which lives in Phase 06, not here).

## Files likely to inspect

- `docs/network/TODO.md`, `docs/network/bond-ports.md`, `docs/network/vlans.md`,
  `docs/network/logical-ports.md`
- `docs/qos/TODO.md`
- `docs/block-storage/TODO.md`, `docs/file-storage/TODO.md`, `docs/snapshots/TODO.md`
- `docs/replication-hypermetro/TODO.md`

## Files likely to modify

- `docs/network/TODO.md` (stale reference fix; possible strike-through of already-done polish
  items)
- `docs/qos/TODO.md` (glossary / reporting examples, if added)
- Other domain `TODO.md` files only if genuinely-open items are found during the re-check.

## Safety considerations

- None — docs-only. Verify no lab IP or credential material is introduced (see verification
  commands).

## Testing strategy

- N/A — docs-only, no test run required.

## Verification commands

```powershell
git diff --check
git status --short
Select-String -Path docs -Pattern '10\.10\.10\.24' -Recurse
Select-String -Path docs -Pattern 'validation|gap-analysis' -Recurse -Include *.md
Select-String -Path docs/network/TODO.md -Pattern 'post-merge-phase'
```

## Dependencies

- The Replication/HyperMetro "Documentation" item (live-evidence refresh) depends on Phase 04's
  scheduled sessions actually running — cannot be resolved by this docs-only phase alone.

## Completion criteria

- Stale network cross-reference fixed; QoS glossary/reporting items added or confirmed unnecessary;
  each domain's Low Priority / Polish list reflects only genuinely still-open items after
  reconciling against the `c79921a` Phase 08 pass.

## Risks / notes

- Low risk. Main pitfall to avoid: duplicating polish work already done in commit `c79921a` — always
  check current doc content before adding a "new" example that may already exist.
