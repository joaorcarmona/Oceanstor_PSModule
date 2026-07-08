# alpha-v1.0.0 Remaining Open TODOs Phase 02 — CI Signing and Publishing Readiness

**Type:** Decision-only / ops carry-forward (no code changes in this repository).
**Live validation allowed:** No.
**Release-blocking:** No — signing and publishing are independently feature-flagged off; the
module can ship unsigned/unpublished today without violating the alpha gate.

## Purpose

Carry forward the still-open CI/CD signing and publishing decisions that were already identified
in the existing `todo/alpha-v1.0.0-open-issues-phase-02-ci-signing-publishing-readiness.md`. Fresh
evidence confirms nothing has changed since that file was written — both feature flags remain off
and no certificate has been sourced.

## Source TODOs / evidence

- `Oceanstor_PSModule_TODO.md`: "CI/CD signing gated behind `vars.SIGNING_ENABLED` (default off, no
  cert sourced/approved) and publish gated behind `vars.PUBLISH_ENABLED` (default off). Follow-up:
  obtain/approve a code-signing certificate and flip `SIGNING_ENABLED`; do a first manual
  `PUBLISH_ENABLED` dry run."
- `todo/alpha-v1.0.0-open-issues-phase-02-ci-signing-publishing-readiness.md` (existing file, not
  modified by this task — this phase only confirms the item is still open and re-states it in the
  new plan family for continuity).

## Current repository evidence

- `.github/workflows/release.yml` lines ~132–147: signing step checks
  `vars.SIGNING_ENABLED == 'true'`; when false, logs `::notice::` and re-uploads the artifact
  unsigned.
- `.github/workflows/release.yml` lines ~210–224: publish step checks
  `vars.PUBLISH_ENABLED == 'true'`; when false, performs a dry-run publish against a disposable
  local `PSRepository` only, never the real PowerShell Gallery.
- No repository variable change, certificate file, or workflow edit has landed since the existing
  Phase 02 file was written — both gates are still off.

## Classification

| Item | Classification |
|---|---|
| Code-signing certificate sourcing/approval | Blocked — external org decision, not a repo task |
| First manual `PUBLISH_ENABLED` dry run | Blocked — requires a maintainer to flip the repo variable and observe a real run |

## Scope

- Re-confirm both flags are still off and no certificate exists (done above).
- Restate the two outstanding action items in this plan family for visibility alongside the rest
  of the remaining-open-todos set.

## Out of scope

- Do not create, request, or approve a code-signing certificate.
- Do not flip `vars.SIGNING_ENABLED` or `vars.PUBLISH_ENABLED` in the GitHub repository settings.
- Do not modify `.github/workflows/release.yml`.
- Do not publish the module to the PowerShell Gallery or any other feed.

## Implementation tasks

None for this task (decision/ops-only). When a maintainer is ready:

1. Obtain and register a code-signing certificate through the org's normal process; store its
   secret reference in the repository/environment secrets (never in-repo).
2. Flip `vars.SIGNING_ENABLED = true` and run the release workflow once against a test tag to
   confirm signing succeeds and the artifact validates.
3. Flip `vars.PUBLISH_ENABLED = true` for a single manual dry run against a disposable feed (or,
   once confident, a real pre-release version) before relying on it for an unattended release.

## Files likely to inspect

- `.github/workflows/release.yml`
- `Oceanstor_PSModule_TODO.md`
- `todo/alpha-v1.0.0-open-issues-phase-02-ci-signing-publishing-readiness.md`

## Files likely to modify

- None in this task.

## Safety considerations

- Flipping `PUBLISH_ENABLED` is effectively irreversible for a real Gallery publish (versions
  cannot be unpublished/reused) — must only be done deliberately by a maintainer, never as part of
  automated planning work.

## Testing strategy

- N/A — no code changes.

## Verification commands

```powershell
git diff --check
git status --short
Select-String -Path .github/workflows/release.yml -Pattern 'SIGNING_ENABLED|PUBLISH_ENABLED'
```

## Dependencies

- Certificate sourcing is an organizational/business decision outside this repository's control.

## Completion criteria

- This phase is complete as a planning carry-forward once committed; it does not resolve until a
  maintainer performs the two external actions listed above.

## Risks / notes

- No new risk introduced; this phase only documents an already-known, already-mitigated (by
  feature flag) gap.
