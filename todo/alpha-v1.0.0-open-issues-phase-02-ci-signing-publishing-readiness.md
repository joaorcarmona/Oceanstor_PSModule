# alpha-v1.0.0 Open Issues Phase 02 — CI, Signing, and Publishing Readiness

**Type:** Release-gate + Decision-only (+ optional small CI-YAML config change). **Live validation:** none.
**Release-blocking:** PARTLY — the signing/publish decisions and the tag convention must be
settled before a real v1.0.0 tag, but they are separable from the code gate (Phase 01).

## Purpose

Settle the release-mechanics decisions and conventions that stand between a green gate and an
actual tag/publish: the tag-vs-`ModuleVersion` guard convention, the code-signing certificate
decision, the first supervised publish dry-run, and one package-hygiene cleanup.

## Source TODOs / evidence

- `todo/release-readiness-go-no-go.md` §4 (tag-guard finding, workflow readiness), §7 (package
  hygiene note), §10.4 (use `v1.0.0` tag).
- `Oceanstor_PSModule_TODO.md:24` — release pipeline shipped (Phase 09); **Follow-up: obtain/approve
  a code-signing certificate and flip `SIGNING_ENABLED`; do a first manual `PUBLISH_ENABLED` dry
  run before relying on it unattended.**

## Current repository evidence

- `.github/workflows/release.yml` (trigger `release: published`): `validate` runs
  `Test-ModuleManifest`, a `$tag.TrimStart('v','V')`-vs-`ModuleVersion` string guard, then
  `Invoke-UnitTests.ps1 -FailOnAnalyzerIssue`. **Tag-guard finding:** the guard ignores
  `PrivateData.PSData.Prerelease`; a tag `v1.0.0-alpha1` fails (`'1.0.0-alpha1' -ne '1.0.0'`).
  Correct tag is `v1.0.0` (prerelease conveyed via the manifest `Prerelease` field only).
- `sign` job gated behind `vars.SIGNING_ENABLED` (default off → logs `::notice::`, re-uploads
  unsigned). No signing cert sourced/approved yet.
- `publish` job gated behind `github.ref == 'refs/heads/master'` AND `vars.PUBLISH_ENABLED`
  (default off → always dry-runs to a disposable local `LocalDryRun` PSRepository). No real
  publish attempted.
- Third-party Actions pinned to commit SHAs; secrets referenced only via `secrets:` context,
  never echoed. `package` job stages only `./POSH-Oceanstor/*`.
- Package hygiene: `.archived-commands/` is gitignored, but one legacy tracked file
  (`.archived-commands/system-management-validation-report.md`) predates the ignore rule. Not
  shipped by the package job, but a repo-hygiene cleanup.

## Scope

- **Decision:** confirm the tag convention (`v1.0.0`, not `v1.0.0-alpha1`) and document it where a
  releaser will see it (RELEASE_NOTES header and/or a release runbook). Optionally adjust the
  guard to strip a `-<prerelease>` suffix — a small, clearly-in-scope release-readiness change.
- **Decision:** code-signing — either source/approve a certificate and flip `vars.SIGNING_ENABLED`,
  or explicitly accept shipping this alpha unsigned (already stated in RELEASE_NOTES) and defer.
- **Action:** perform one supervised `PUBLISH_ENABLED` dry-run review (dry-run only, no real
  Gallery publish) and record the outcome.
- **Cleanup:** remove or re-ignore the legacy tracked `.archived-commands` report file.

## Out of scope

- Any real `Publish-Module` to the PowerShell Gallery. Any git tag/push. Any secret creation.
- Broad CI redesign — only the optional prerelease-suffix guard tweak is permitted here.
- The code/test gate itself → Phase 01.

## Implementation tasks

1. Record the tag convention decision; if adjusting the guard, edit only the tag-normalization line
   in `release.yml` and add a unit/README note.
2. Signing decision: document the outcome; if proceeding, add cert material via repo secrets
   (outside this planning scope) and flip `vars.SIGNING_ENABLED`. If deferring, note it as an
   accepted alpha limitation.
3. Publish dry-run: run/observe the `LocalDryRun` publish path on a branch build; capture the log
   (redacted) as evidence.
4. `git rm --cached .archived-commands/system-management-validation-report.md` (or confirm the
   ignore rule now covers it) so it stops tracking.

## Files likely to inspect

- `.github/workflows/release.yml`, `.github/workflows/powershell.yml`
- `POSH-Oceanstor/POSH-Oceanstor.psd1` (`ModuleVersion`, `Prerelease`), `RELEASE_NOTES.md`
- `.gitignore`, `.archived-commands/`

## Files likely to modify

- `.github/workflows/release.yml` (only the optional guard tweak), `RELEASE_NOTES.md` (tag/signing
  note), `.gitignore` and/or removal of the one tracked archived file.

## Safety considerations

- No live array access. Never echo secrets. Never perform a real publish or tag in this phase.
- Treat signing-certificate handling as secret material — repo settings/secrets only, never in a
  file or log.

## Testing strategy

- Validate any YAML edit with a dry `act`/branch CI run or `Test-ModuleManifest` locally.
- Confirm the dry-run publish path still reports publishability without touching the real Gallery.

## Verification commands

```powershell
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
git ls-files .archived-commands/    # expect empty after cleanup
```

## Dependencies

- Phase 01 must be green before a real tag would pass `validate`. Signing/publish decisions can be
  taken in parallel but must not be exercised until the gate is green.

## Completion criteria

- Tag convention documented (and guard adjusted or explicitly left as-is with `v1.0.0` guidance).
- Signing decision recorded (flip or documented deferral).
- One supervised publish **dry-run** reviewed and its outcome recorded.
- Legacy `.archived-commands` file no longer tracked.

## Risks / notes

- Flipping `PUBLISH_ENABLED` prematurely risks an unintended real publish — keep default off until
  a human explicitly approves the first real release.
