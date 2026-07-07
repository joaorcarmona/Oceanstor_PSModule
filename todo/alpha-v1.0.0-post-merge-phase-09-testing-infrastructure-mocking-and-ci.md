# alpha-v1.0.0 Post-Merge Phase 09 — Testing Infrastructure: API Mocking and Release Pipeline

## Purpose

Deliver the two remaining infrastructure items from the root backlog: a reusable
mock-response library that mimics real OceanStor v6 REST responses (so code paths are
testable without a SAN), and an automated, signed release pipeline to the PowerShell
Gallery triggered by GitHub Release tags.

## Source TODOs / evidence

- `Oceanstor_PSModule_TODO.md` § Testing, CI/CD, & Supply Chain Security (verified open):
  - "**Develop Robust API Mocking** — Build comprehensive `Mock Invoke-RestMethod`
    templates that mimic real Huawei OceanStor v6 responses… without requiring a
    physical SAN connection."
  - "**Automate Release Pipeline to PowerShell Gallery** — … signs, packages, and
    publishes a validated versioned module … on GitHub Release tags."
- `docs/testing/unit-tests.md`, `Tests/README.md` — current mock conventions the library
  must formalize rather than replace.
- `.github/workflows/powershell.yml` — existing CI (Analyzer SARIF + Pester matrix on
  windows/ubuntu/macos, Pester pinned 5.7.1) that the release pipeline extends.

Deduplication decision:
Harness *reporting* fixes are Phase 02, not here. Live-validation runbooks live in their
domain phases (04, 06, 07). This phase is offline test infrastructure and CI/CD only.

## Scope

- [Tests] Mock library design: centralized fixture module (e.g.
  `Tests/Unit/Support/DMResponseFixtures.psm1` or `.psd1` data files) providing
  canonical success/error/paged/empty response objects per endpoint family (lun, host,
  filesystem, alarm, DR, network), sourced from the REST reference's documented example
  responses and sanitized live captures. Include the known tricky shapes: `range=` paged
  envelopes, identical-page loop case, `error.Code` non-zero bodies, session-expired
  code `1077939726`, fuzzy-vs-exact filter results.
- [Tests] Migrate a pilot slice of existing tests (one getter family, one mutator
  family) onto the fixtures to prove the pattern; do not mass-migrate 48 test files in
  one pass.
- [Code] Release pipeline workflow: on GitHub Release tag —
  `Test-ModuleManifest` + version/tag agreement check → ScriptAnalyzer (fail on issues)
  → full Pester matrix → package → Authenticode/catalog signing step (requires a signing
  cert decision) → `Publish-Module`/`Publish-PSResource` to the Gallery with an API key
  from repository secrets.
- [Safety review] Supply-chain review of the pipeline: pinned action versions, least
  privilege for the Gallery key, no secret echoing, artifact provenance.
- [Docs-only] `docs/testing/unit-tests.md` fixture-usage section; release process
  documented in `RELEASE_NOTES.md`-adjacent internal notes.

## Out of scope

- Rewriting existing green tests wholesale.
- Any live array dependency in unit tests — the point is the opposite.
- Choosing the certificate vendor / key custody (needs a human decision; the pipeline
  lands with signing as a clearly marked stage, skippable until the cert exists).

## Implementation tasks

- [Tests] Fixture inventory: enumerate endpoint families actually mocked today
  (grep `Mock Invoke-RestMethod` / `Invoke-DeviceManager` mocks) and rank by reuse.
- [Tests] Build fixture module + pilot migration; assertion helpers for resource-string
  matching that tolerate `?range=`/`&range=` (existing `-BeLike` convention).
- [Code] `.github/workflows/release.yml` (new) with the stage chain above; version-bump
  guard comparing tag to `ModuleVersion`.
- [Safety review] Secrets handling review; dry-run publish against a test feed or
  `-WhatIf` publish before enabling the real Gallery push.
- [Docs-only] Update testing docs; note the Pester 5 ceiling (5.99.99) applies to the
  pipeline too.

## Files likely to inspect

- `Tests/Unit/**/*.Tests.ps1` (mock patterns), `Tests/Invoke-UnitTests.ps1`
- `.github/workflows/powershell.yml`, `PSScriptAnalyzerSettings.psd1`
- `POSH-Oceanstor.psd1` (packaging metadata: tags, license, project URI)

## Files likely to modify

- New fixture module under `Tests/Unit/Support/` (or repo-conventional location)
- Pilot test files; new `.github/workflows/release.yml`
- `docs/testing/unit-tests.md`, `Tests/README.md`

## Safety considerations

- No live array involvement. Fixtures must be sanitized: no real hostnames, serials,
  WWNs from the production-adjacent lab, and never the lab IP in committed fixtures.
- Gallery API key only via GitHub secrets; publish job restricted to release tags on
  `master`.

## Testing strategy

1. Fixture module has its own unit tests (shape guarantees).
2. Pilot-migrated files green locally and in CI matrix.
3. Release workflow validated with a dry-run tag on a fork/test feed before first real
   publish.

## Verification commands

```powershell
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
git diff --check; git diff --stat
```

## Dependencies

- Phase 01. No hard dependency on Phases 02-08, but Phase 11 (release readiness)
  depends on this phase's pipeline existing.

## Completion criteria

- Fixture library shipped with pilot adoption and documented usage.
- Release workflow merged; a dry-run tag produces a signed (or explicitly
  signing-skipped) package that passes all gates; real publish blocked only on the
  signing-cert decision.

## Risks / notes

- Signing requires an organizational certificate decision — flag early; the pipeline
  should not silently publish unsigned if signing was intended.
- Fixture drift vs real array behavior is a permanent risk; the integrity harness
  remains the ground-truth check, fixtures are for offline breadth.
