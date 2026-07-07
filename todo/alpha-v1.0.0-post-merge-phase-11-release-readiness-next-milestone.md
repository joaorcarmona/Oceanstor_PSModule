# alpha-v1.0.0 Post-Merge Phase 11 — Release Readiness for the Next Alpha/Beta Milestone

## Purpose

Gate the next published milestone (v1.0.0-beta or the next alpha) on a clean,
evidence-backed checklist: version bump, release notes, manifest/export integrity, full
test matrix, a read-only live validation run with the post-Phase-02 report semantics,
and a go/no-go review of which phases actually shipped.

## Source TODOs / evidence

- Current state verified on `alpha-v1.0.0`: `ModuleVersion = 0.9.5`, 299 exported
  commands exactly matching `POSH-Oceanstor/Public/*.ps1`.
- `RELEASE_NOTES.md` — release-facing summary convention (v0.9.4/v0.9.5 entries as
  templates).
- All prior phase files in `.archived-commands/alpha-v1.0.0-post-merge-phase-*.md` —
  their Completion criteria feed this checklist.
- `Reports/getter-integrity-last-result.md` — the standing live-run evidence artifact.

Deduplication decision:
This phase implements nothing. Every functional item lives in Phases 02-09; anything
found broken here is routed back to its owning phase, not patched ad hoc during release
prep.

## Scope

- [Docs-only] `RELEASE_NOTES.md` entry for the milestone: new commands (certificates,
  quorum getter, failover-group member getter, any Phase 08 accepts), behavior changes
  (e.g. `Get-DMdnsServer` typed output — breaking-change note), harness changes
  (`NotRequested` status), alias/compat notes.
- [Code] Version bump in `POSH-Oceanstor.psd1` (single-line change) consistent with the
  chosen tag; prerelease tag in `PrivateData.PSData.Prerelease` if publishing an
  alpha/beta to the Gallery.
- [Tests] Full local gate: manifest test, import + command discovery, full unit suite
  with analyzer enabled (not `-SkipAnalyzer` for the release gate), CI matrix green.
- [Live-validation planning] One read-only live validation run (no mutating switches,
  optionally `-IncludePerformance` for the performance read checks) as release evidence;
  confirm report shows `NotRequested`/`SkippedUnsafe`/`NotConfigured` correctly and
  `Blocked = 0`.
- [Safety review] Final sweep: every mutator still declares `SupportsShouldProcess`;
  no public doc leaks (Phase 10 verifications re-run); `.archived-commands/` still
  gitignored so internal plans don't ship in the package. Confirm the packaged module
  contains only `POSH-Oceanstor/` content.

## Out of scope

- Implementing or fixing anything found — route back to owning phase.
- Mutating live validation (only if a domain phase's runbook was separately executed
  and its evidence is already on file).
- The actual `git tag`/publish action without explicit user instruction.

## Implementation tasks

- [Docs-only] Draft release notes from phase completion evidence.
- [Code] Version + prerelease metadata bump.
- [Tests] Run the full gate; attach results.
- [Live-validation planning] Schedule the read-only evidence run (human-triggered;
  internal target `$storageIP = '10.10.10.24'` with `-SkipCertificateCheck`).
- [Safety review] Go/no-go review meeting notes: which phases shipped, which TODOs
  remain open into the next cycle (feed back into the domain TODO files).

## Files likely to inspect

- `POSH-Oceanstor.psd1`, `RELEASE_NOTES.md`, `Reports/getter-integrity-last-result.md`
- `.github/workflows/powershell.yml` + `release.yml` (Phase 09)

## Files likely to modify

- `POSH-Oceanstor.psd1` (version/prerelease), `RELEASE_NOTES.md`
- Domain `TODO.md` files (carry-over items)

## Safety considerations

- Read-only live run only; no mutating switches for release evidence.
- No publish/tag/push without explicit user instruction — pipeline (Phase 09) does the
  mechanical work once a human creates the release.

## Testing strategy

1. `Test-ModuleManifest`, import smoke, `Get-Command` count check (299 + phase adds).
2. Full unit suite with analyzer enforced; CI matrix on the release PR.
3. Read-only live validation run as evidence; archive the report.

## Verification commands

```powershell
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
Get-Command -Module POSH-Oceanstor
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -Output Normal
Get-ChildItem -Recurse docs -File | Where-Object { $_.Name -match 'validation|gap-analysis' }
Get-ChildItem -Recurse docs -File -Include *.md | Select-String -Pattern '10\.10\.10\.24'
git diff --check; git status; git diff --stat
```

## Dependencies

- Phases 02 (report semantics), 09 (pipeline), 10 (docs sweep) are hard gates.
- Phases 03-08: whichever shipped is included; unshipped items are explicitly listed as
  known gaps in the release notes rather than blocking, per alpha/beta expectations.

## Completion criteria

- All gate commands green; live read-only report archived with `Blocked = 0` and correct
  opt-in labeling; release notes accurate; version metadata consistent with the intended
  tag; go/no-go decision recorded.

## Risks / notes

- Publishing a prerelease to the Gallery makes the module surface public and cached —
  breaking-change notes (DNS typed output, any renamed parameters) must be in the notes
  *before* the tag, not after.
- If the signing-certificate decision (Phase 09) is still open, the release must
  explicitly state the package is unsigned rather than silently shipping.
