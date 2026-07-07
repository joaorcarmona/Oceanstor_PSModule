# alpha-v1.0.0 Post-Merge Phase 08 — Block/File/NAS Command-Coverage Decisions

## Purpose

Resolve the remaining open "Command Coverage Decisions" in the root backlog — decisions
first, implementation only where the decision is "yes". These govern whether mapping
views, storage pools, NAS children, and initiators gain modification surface. No new
cmdlet is invented; each candidate must be justified by a documented REST endpoint and a
real operator need.

## Source TODOs / evidence

- `Oceanstor_PSModule_TODO.md` § Active Backlog / Command Coverage Decisions (verified
  open checkboxes):
  - "Decide whether mapping views need `Set-DMMappingView`, `Rename-DMMappingView`, and
    a matching object `Rename()` method."
  - "Decide whether storage pools need supported Set/Rename commands … confirm the
    Huawei API behavior for each supported device generation first."
  - "Decide which NAS children need modification commands: dTrees, CIFS shares, NFS
    shares, and NFS clients currently support only … create/read/delete."
  - "Decide whether initiator objects need action methods or should remain command-only."
  - (Fifth item — network read-only vs mutation — closed in Phase 01 as
    resolved-by-code by the merged network branch.)

Deduplication decision:
No `docs/block-storage/`, `docs/file-storage/`, `docs/qos/`, or `docs/snapshots/` TODO
files exist on this branch — block/file/QoS/snapshot documentation TODOs named in the
task brief are **not present**; the only open block/file work is this decision list in
the root TODO. QoS and snapshot surfaces carry no open TODO anywhere (the earlier
class-literal OutputType defect there was already fixed module-wide per the DR TODO's
Recently Completed) — so no QoS/snapshot phase exists, deliberately.

## Scope

- [Safety review] For each of the four decisions: check the 6.1.6 REST reference for a
  documented modify/rename endpoint; check DeviceManager parity (does the UI offer it);
  weigh operator demand; record Accept/Reject with reasons directly in
  `Oceanstor_PSModule_TODO.md` (Rejected section pattern already exists there).
- [Code] For each Accept: implement following the established module patterns —
  `New-DMNamedObjectUpdate` shared helper for Set/Rename where applicable,
  `SupportsShouldProcess`, pipeline `begin/process/end` with per-item error semantics,
  `ValueFromPipelineByPropertyName` identity binding with correct `[Alias]`,
  `ConvertTo-DMRequestBody`-style bound-parameter gating.
- [Tests] Unit tests per new command: WhatIf no-API-call, pipeline multi-item,
  continue-on-error, mock schema from the REST reference.
- [Code] If any Accept produces a Set command, extend the corresponding mutation
  workflow (`Lun.ps1`/`Nas.ps1` pattern) with a test-owned lifecycle step + read-back
  verification, config-gated as usual.
- [Docs-only] Update the root TODO checkboxes and any affected topic docs.

## Out of scope

- QoS, snapshots, HyperCDP — no open TODOs.
- Inventing modification commands for objects whose endpoints don't document modify.
- Object-method surface beyond the established `Rename()`/`Delete()` convention.

## Implementation tasks

- [Safety review] Decision memo per item (internal), Accept/Reject recorded in root TODO.
- [Code] Implement accepted commands (likely candidates given DeviceManager parity:
  `Set-DMMappingView`/`Rename-DMMappingView`; NAS-child description/permission edits
  where documented).
- [Tests] Full unit pattern per new command; `ModuleInventory.Tests.ps1` will enforce
  manifest/coverage registration automatically.
- [Code] Workflow extension for accepted Set commands with read-back assertion
  (description persisted), mirroring `Set-DMLunGroup` verification style.
- [Docs-only] Root TODO updates; `RELEASE_NOTES.md` entries staged for Phase 11.

## Files likely to inspect

- `OceanStor Dorado 6.1.6 REST Interface Reference.md` (mappingview, storagepool,
  fsdir/dtree, CIFSHARE/NFSHARE/NFS_SHARE_AUTH_CLIENT, initiator endpoints)
- `POSH-Oceanstor/Private/New-DMNamedObjectUpdate.ps1` and existing Set-* commands
- `POSH-Oceanstor/Private/class-*.ps1` for method-surface conventions

## Files likely to modify

- New/changed `POSH-Oceanstor/Public/*.ps1` per accepted decision
- `POSH-Oceanstor.psd1`, `Tests/ModuleCoverage.psd1`, unit test files
- `Tests/Integration/Private/Workflows/{Lun,Nas,...}.ps1` for accepted Sets
- `Oceanstor_PSModule_TODO.md`

## Safety considerations

- Storage pools: modification is high-blast-radius (capacity/tier policy). If accepted
  at all, live validation must be `SkippedUnsafe` — pools cannot be test-owned cheaply.
- Mapping views: renames affect host access paths; workflow coverage only on a
  test-owned mapping view created in the same run.
- NAS children: never modify pre-existing shares/clients; test-owned only, ID-captured
  cleanup in `finally`.

## Testing strategy

1. Unit-first (mocked schemas); full suite; ScriptAnalyzer.
2. Workflow dry run gated off → `NotConfigured`.
3. Accepted Set commands validated live only inside the existing gated mutation runs on
   test-owned objects.

## Verification commands

```powershell
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
git diff --check; git diff --stat
```

## Dependencies

- Phase 01 (closes the network decision, confirms these four remain). Independent of
  Phases 03-07; schedule after them — decisions are not release-blocking.

## Completion criteria

- All four checkboxes resolved in the root TODO with recorded rationale.
- Every accepted command shipped with the full test pattern; every rejection documented
  in the Rejected section with the endpoint/parity evidence.

## Risks / notes

- The storage-pool decision explicitly requires confirming per-generation API behavior —
  if only Dorado 6.x behavior is verifiable on the lab array, scope the decision to that
  generation and say so.
- `Set-DMHost`'s known full-fetch collision-check constraint (via
  `New-DMNamedObjectUpdate`) may resurface here; do not regress the documented
  performance fixes when reusing that helper.
