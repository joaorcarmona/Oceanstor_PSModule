# alpha-v1.0.0 Post-Merge Phase 10 — Public Documentation Consistency Cleanup

## Purpose

Bring the public documentation set (README.md, docs/**) into full consistency after the
four-branch merge: fix broken/miscased links, remove stale "not yet implemented" text
made false by earlier phases, verify naming conventions, and confirm no internal
material (lab IPs, validation reports, gap analyses) leaks into public docs.

## Source TODOs / evidence

- `docs/system-management/README.md:16` — links `[CERTIFICATES.md](CERTIFICATES.md)` but
  the file on disk is lowercase `certificates.md` (breaks on case-sensitive hosts, e.g.
  GitHub Pages/Linux checkouts); also violates the "only README/TODO uppercase" rule.
- `docs/network/logical-ports.md:83` — "not implemented in the integration harness yet"
  (goes stale after Phase 06).
- `docs/testing/*.md` — `Blocked`-caveat text removed by Phase 02; re-verify no stragglers.
- `docs/system-management/certificates.md` status line — updated by Phase 5; re-verify.
- Repository conventions (project instructions): no public `VALIDATION-REPORT.md` /
  `GAP-ANALYSIS.md`-style files under `docs/`; internal reports live in
  `.archived-commands/` (verified currently true: gap/validation reports are already
  under `.archived-commands/`).
- Per-domain TODO discipline: root `Oceanstor_PSModule_TODO.md` is the intentional
  global backlog; domains each have one TODO.md — keep it that way.

Deduplication decision:
Each functional phase updates the docs it makes stale — this phase is a final sweep and
convention audit, not the primary owner of those edits. Only genuinely cross-cutting
fixes (casing, dead links, leaked IPs) originate here.

## Scope

- [Docs-only] Link audit across `README.md` + `docs/**`: every relative link resolves
  with exact case on disk.
- [Docs-only] Filename-convention audit: only `README.md`/`TODO.md` uppercase; all other
  docs lowercase.
- [Docs-only] Stale-text sweep for claims contradicted by shipped phases
  ("not implemented", "proposed but not yet implemented", "currently none exist").
- [Docs-only] Sanitization sweep: no `10.10.10.24`, no credential material, in any file
  under `docs/` or `README.md`; public examples use `$storageIP = 'StorageIP'` and
  `Import-Clixml` credential pattern.
- [Docs-only] Confirm no validation/gap-analysis files exist under `docs/`.
- [Docs-only] Cross-domain TOC check: each domain README's page table matches the files
  actually present.

## Out of scope

- Content rewrites of topic pages (owned by domain phases).
- Any code or test change.
- `.archived-commands/` contents (internal, gitignored — not public docs).

## Implementation tasks

- [Docs-only] Fix the `CERTIFICATES.md` link casing in `docs/system-management/README.md`.
- [Docs-only] Run the audits above; fix findings; note each fix in the commit message
  (when a commit is requested).
- [Docs-only] Verify domain TODO files end the phase accurately reflecting all completed
  phases (coordination with Phase 01's inventory format).

## Files likely to inspect

- `README.md`, all of `docs/**`, `Tests/README.md`, `RELEASE_NOTES.md`

## Files likely to modify

- `docs/system-management/README.md` (link case) and whatever the audits surface —
  expected small.

## Safety considerations

- Documentation-only; no live access, no code.
- Do not delete internal reports — they are already correctly outside `docs/`.

## Testing strategy

- Static audits only; no unit tests required (assert none were touched).

## Verification commands

```powershell
# Unwanted public validation/gap files
Get-ChildItem -Recurse docs -File | Where-Object { $_.Name -match 'validation|gap-analysis' }

# Lab IP leakage in public docs
Get-ChildItem -Recurse docs -File -Include *.md | Select-String -Pattern '10\.10\.10\.24'

# Case-exact relative-link audit (manual or scripted sweep)
git diff --check
git status
git diff --stat
```

## Dependencies

- Runs after Phases 02-08 have landed their own doc updates (final sweep). The link-case
  fix can happen any time.

## Completion criteria

- Zero broken/miscased relative links; zero lab-IP or credential leakage in public docs;
  zero validation/gap files under `docs/`; conventions hold; both verification searches
  return empty.

## Risks / notes

- On Windows (case-insensitive FS) miscased links appear to work locally — the audit
  must compare against `git ls-files` exact names, not `Test-Path`.
