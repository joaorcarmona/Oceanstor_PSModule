# Release Readiness Go/No-Go — v1.0.0-alpha1

**Phase:** `alpha-v1.0.0-post-merge-phase-11-release-readiness-next-milestone.md`
**Date:** 2026-07-07
**Branch:** `alpha-v1.0.0`
**Target version:** `ModuleVersion = 1.0.0`, `PrivateData.PSData.Prerelease = alpha1`

This phase implements nothing functional. It verifies, documents, and records a
decision. Anything found broken is routed back to its owning phase below, not
patched here.

## Current hard-gate decision: **GO** (as of the Phase 01 update, 2026-07-07)

The release pipeline's hard gate now **passes**: `./Tests/Invoke-UnitTests.ps1
-FailOnAnalyzerIssue -Output Normal` reports **0 Error-severity analyzer findings and
1232/1232 tests passing** (see the Phase 01 update note below and §3a). This supersedes the
original **NO-GO** evidence run recorded immediately after, which is preserved verbatim for
traceability.

Separately tracked, non-gating release-readiness items remain open and do **not** change this
hard-gate decision:

- Code-signing certificate sourcing/approval and the first supervised publish dry-run
  (CI `SIGNING_ENABLED` / `PUBLISH_ENABLED` still default off) — tracked in Phase 02.
- Supervised live-mutation validation of a few shipped mutators, including the
  `Set-DMSnmpTrapServer` / `Test-DMSnmpTrapServer` `50331651` update-payload defect — tracked
  in Phase 04 (create/remove already validated, so this is not a hard-gate blocker).

---

## Decision: **NO-GO** (original 2026-07-07 evidence run — SUPERSEDED, retained for history)

The release pipeline's hard gate
(`./Tests/Invoke-UnitTests.ps1 -FailOnAnalyzerIssue` in `.github/workflows/release.yml`,
`validate` job) would **fail** against the current working tree: PSScriptAnalyzer
reports 2 `Error`-severity findings, and the Pester suite has 39 failing tests. Neither
condition is caused by this phase (no production cmdlet or test code was touched here);
both are pre-existing gaps surfaced by running the full, analyzer-enabled gate for the
first time as part of release prep.

Tagging/publishing now would ship a version whose own CI gate cannot pass — the
`release.yml` `validate` job would go red on the first real release attempt.

> **Phase 01 update (2026-07-07): gate criterion now GO.** The release-blocker
> gate (Phase 01, `todo/alpha-v1.0.0-open-issues-phase-01-release-blockers-gate.md`)
> was implemented. `./Tests/Invoke-UnitTests.ps1 -Output Normal` and the release
> gate `-FailOnAnalyzerIssue -Output Normal` now both pass: **0 Error-severity
> analyzer findings, 0 failing tests (1232/1232)**. The 2 SNMP USM Errors were
> cleared with a justified `[SuppressMessageAttribute]` (see §3a); the 39 test
> failures below were resolved by subsequent merges and re-verified green. The
> remaining 93 Warning / 24 Information analyzer results are non-blocking and
> deferred. The evidence below is retained as the original Phase 11 snapshot.

## 1. Version / prerelease metadata

- `POSH-Oceanstor/POSH-Oceanstor.psd1`: `ModuleVersion = '1.0.0'`,
  `PrivateData.PSData.Prerelease = 'alpha1'`. Confirmed via `Test-ModuleManifest`
  (`ModuleVersion: 1.0.0  Prerelease: alpha1`).

## 2. Manifest / export / import validation — PASS

```
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1   → OK
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force  → OK
Get-Command -Module POSH-Oceanstor (Function)               → 304
Public/*.ps1 file count                                     → 304
Match                                                        → True
```

No export drift.

## 3. Full unit + analyzer gate — **FAIL**

Command run: `./Tests/Invoke-UnitTests.ps1 -Output Normal` (PSScriptAnalyzer +
ImportExcel installed locally for this run; no `-SkipAnalyzer`).

```
PSScriptAnalyzer: 119 issues — 93 Warning, 24 Information, 2 Error
Discovery: 1232 tests in 96 files
Tests Passed: 1193, Failed: 39, Skipped: 0, Inconclusive: 0
Runtime: 111.67s
```

### 3a. Analyzer errors (hard gate blockers)

| File | Line | Rule | Detail |
|---|---|---|---|
| `New-DMSnmpUsmUser.ps1` | 10 | `PSAvoidUsingUsernameAndPasswordParams` | Function has both `Username` and `Password` parameters |
| `Set-DMSnmpUsmUser.ps1` | 10 | `PSAvoidUsingUsernameAndPasswordParams` | Function has both `Username` and `Password` parameters |

Routed to `docs/system-management/TODO.md` (High Priority item 3, added this phase).
Not fixed here — no production cmdlet code changes are in scope for Phase 11, and a fix
requires a parameter-contract decision (`SecureString`/`PSCredential` redesign of the
SNMPv3 USM user surface) that belongs to system-management ownership.

### 3b. Test failures — full list (39/39 accounted for)

Grouped by symptom cluster to aid routing; each cluster is a candidate follow-up, not a
Phase 11 fix.

**Cluster A — "not just the last one" pipeline dispatch (6 tests).** Multi-item pipeline
input resolves to 0/`$null` instead of processing every piped item. Pattern matches the
`begin`/`process`/`end` pipeline refactor tracked in `Oceanstor_PSModule_TODO.md`'s
"Native Pipeline & Context Architecture" section — most likely stale test
fixtures/mocks relative to that refactor, not a fresh regression.
- `Tests/Unit/Public/group-membership-actions.Tests.ps1:188` — associates every LUN piped in, not just the last one
- `Tests/Unit/Public/group-membership-actions.Tests.ps1:243` — removes every LUN membership piped in, not just the last one
- `Tests/Unit/Public/HyperCDPSchedule.Tests.ps1:185` — removes every piped LUN from a HyperCDP schedule
- `Tests/Unit/Public/initiator-actions.Tests.ps1:246` — removes every Fibre Channel initiator piped in from the same host, not just the last one
- `Tests/Unit/Public/mapping-view-actions.Tests.ps1:474` — maps every LUN piped into Add-DMmapLunToHost to the same host, not just the last one
- `Tests/Unit/Public/mapping-view-actions.Tests.ps1:621` — maps every LUN group piped into Add-DMmapLunGroupToHost to the same host, not just the last one

**Cluster B — mapping-view / group membership single-item dispatch (4 tests).** Same
`$null`/0-vs-expected symptom on non-pipeline (single-call) paths in the same test files
as Cluster A — likely the same underlying fixture/mock staleness.
- `Tests/Unit/Public/group-membership-actions.Tests.ps1:152` — removes a verified LUN membership through query parameters (mock throws "LUN 'database' is not a member of LUN group 'production'")
- `Tests/Unit/Public/mapping-view-actions.Tests.ps1:284` — removes every LUN group piped in from the mapping view, not just the last one
- `Tests/Unit/Public/mapping-view-actions.Tests.ps1:306` — associates every host group piped in with the mapping view, not just the last one
- `Tests/Unit/Public/mapping-view-actions.Tests.ps1:328` — removes every host group piped in from the mapping view, not just the last one

**Cluster C — LUN-group resolution getters (4 tests).** `Get-DMlun -LunGroupId/-LunGroupName`
and the associated LUN-group object method return 0/`$null` where a result is expected.
- `Tests/Unit/Public/Get-Storage.Tests.ps1:155` — retrieves LUN objects associated with a LUN group through its method
- `Tests/Unit/Public/Get-Storage.Tests.ps1:537` — gets LUNs directly by -LunGroupId without resolving through Get-DMlunGroup
- `Tests/Unit/Public/Get-Storage.Tests.ps1:556` — gets LUNs directly by -LunGroupName, resolving the group first
- `Tests/Unit/Public/Get-Storage.Tests.ps1:574` — gets LUNs directly by piped -LunGroup object

**Cluster D — model-class dispatch (`Private/class-Oceanstor*.ps1`) (8 tests).** Class
methods (`GetSnapshots`, `Delete`, view-assembly constructors) fail on missing/invalid
parameters or `$null` results, independent of the pipeline refactor pattern above —
distinct root cause from Clusters A–C, likely a separate fixture/mock gap in the model
layer.
- `Tests/Unit/Private/Classes.Core.Tests.ps1:62` — deletes a dtree through Remove-DMDTree resolving the parent file system by ID (expected `'documents'`, got `''`)
- `Tests/Unit/Private/Classes.Host.Tests.ps1:68` — retrieves all supported path types from a host object (expected array, got `$null`)
- `Tests/Unit/Private/Classes.Storage.Tests.ps1:259` — creates and retrieves snapshots from a file-system object (`RuntimeException: Invalid FileSystemName`)
- `Tests/Unit/Private/Classes.Storage.Tests.ps1:283` — deletes and rolls back a file-system snapshot object (expected 0, got `$null`)
- `Tests/Unit/Private/Classes.Storage.Tests.ps1:529` — retrieves snapshots for a version 6 LUN object (`RuntimeException: You cannot call a method on a null-valued expression`)
- `Tests/Unit/Private/Classes.Storage.Tests.ps1:801` — deletes named objects through their Remove-DM* commands (expected 0, got `$null`)
- `Tests/Unit/Private/Classes.Views.Tests.ps1:58` — creates a host view with retrieved paths (`ParameterBindingException`: missing `HostId`/`InitiatorType`)
- `Tests/Unit/Private/Classes.Views.Tests.ps1:84` — assembles a storage view from device manager queries (`[System.Object[]]` has no method `split`)

**Cluster E — `Import-DMPerformanceReportCsv` zip handling (5 tests).** All fail with
`RuntimeException: Unable to find type [System.IO.Compression.ZipFile]` inside the
test's own `New-TestReportZip` helper. This is a .NET assembly-loading issue in the test
session (the `System.IO.Compression.FileSystem` assembly isn't loaded before the type is
referenced) — environment-dependent, not obviously caused by production code.
- `Tests/Unit/Private/Import-DMPerformanceReportCsv.Tests.ps1:44` — returns rows from a single CSV file inside the zip
- `Tests/Unit/Private/Import-DMPerformanceReportCsv.Tests.ps1:56` — tags each row with the source filename
- `Tests/Unit/Private/Import-DMPerformanceReportCsv.Tests.ps1:68` — combines rows from multiple CSV files in the zip
- `Tests/Unit/Private/Import-DMPerformanceReportCsv.Tests.ps1:77` — returns an empty array when the zip has no CSV files
- `Tests/Unit/Private/Import-DMPerformanceReportCsv.Tests.ps1:88` — cleans up its temporary extraction directory afterwards

**Cluster F — `Invoke-DeviceManager` / `Connect-deviceManager` parameter mismatches
(7 tests).** Tests call `-Credential` (as mandatory) and `-SkipCertificateCheck` and hit
`ParameterBindingException`s the current parameter surface doesn't support the same way,
plus two response-normalization tests failing on case-conflicting JSON key handling.
Distinct from the pipeline-refactor pattern; looks like tests written against an
auth/session parameter contract that has since evolved.
- `Tests/Unit/Private/Invoke-DeviceManager.Tests.ps1:49` — passes SkipCertificateCheck only when the session opts in
- `Tests/Unit/Private/Invoke-DeviceManager.Tests.ps1:120` — converts a raw string response with case-conflicting JSON keys to a PSCustomObject
- `Tests/Unit/Private/Invoke-DeviceManager.Tests.ps1:127` — falls back to Invoke-WebRequest and normalises case-conflicting JSON keys (message path)
- `Tests/Unit/Private/Invoke-DeviceManager.Tests.ps1:156` — falls back to Invoke-WebRequest when FullyQualifiedErrorId matches WebCmdletCannotConvertContentException
- `Tests/Unit/Public/Connect-deviceManager.Tests.ps1:56` — creates and returns a connection by prompting for credentials by default
- `Tests/Unit/Public/Connect-deviceManager.Tests.ps1:79` — keeps the Secure switch as a credential-prompt compatibility path
- `Tests/Unit/Public/Connect-deviceManager.Tests.ps1:105` — records and uses SkipCertificateCheck only when explicitly requested

**Cluster G — misc / single-instance (4 tests).**
- `Tests/Unit/Private/Invoke-DMPagedRequest.Tests.ps1:134` — falls back to an unpaged request when the array rejects the range parameter (expected 1, got `$null`)
- `Tests/Unit/Public/Get-DMCapacityHistory.Tests.ps1:101` — runs the full create → run → download → parse → cleanup pipeline in order (expected 1, got `$null`)
- `Tests/Unit/Public/Get-DMPerformanceHistory.Tests.ps1:76` — runs the full create → run → download → parse → cleanup pipeline in order (expected 1, got `$null`)
- `Tests/Unit/Public/protection-and-consistency-groups.Tests.ps1:325` — gets the associated LUN group and dispatches deletion from the model (`.GetLunGroup().Name` returns `$null`)

**Cluster H — environment artifact of this gate run, not a code issue (1 test).**
- `Tests/Unit/Private/Test-ModuleRequirements.Tests.ps1:20` — "throws with installation guidance when ImportExcel is unavailable." This test's premise (ImportExcel not installed) was invalidated by Phase 11 installing ImportExcel locally to exercise the Excel-export code paths for this same gate run. Not a defect; would pass again on a clean machine without ImportExcel. No action needed.

**Total: 6 + 4 + 4 + 8 + 5 + 7 + 4 + 1 = 39.**

### 3c. Routing

None of these are fixed in this phase (no production cmdlet or test code changes are in
scope for Phase 11). Recommended routing:
- Clusters A–C (14 tests, pipeline/dispatch `$null`-vs-expected pattern) → the phase(s)
  that own the Native Pipeline & Context Architecture refactor (see
  `Oceanstor_PSModule_TODO.md`), for fixture/mock reconciliation.
- Cluster D (8 tests, model-class layer) → a dedicated Private/class-layer test-fixture
  pass; separate root cause from A–C.
- Cluster E (5 tests, ZipFile type) → testing-infrastructure fix (load
  `System.IO.Compression.FileSystem` in the test helper or module scope before referencing
  `[System.IO.Compression.ZipFile]`).
- Cluster F (7 tests, Connect/Invoke-DeviceManager param surface) → whichever phase last
  touched `Connect-deviceManager.ps1` / `Invoke-DeviceManager.ps1`'s parameter contract,
  to reconcile tests against the current signature.
- Cluster G (4 tests) → individual triage, no shared pattern identified.
- Cluster H (1 test) → no action; self-resolves on a machine without ImportExcel
  pre-installed, or the test should be adjusted to skip/mock module-presence detection
  instead of relying on the real environment state.

## 4. CI / release workflow readiness

`.github/workflows/release.yml` (229 lines, trigger `release: types: [published]`):
- `validate` job: `Test-ModuleManifest`, then a tag-vs-`ModuleVersion` guard, then
  `./Tests/Invoke-UnitTests.ps1 -FailOnAnalyzerIssue -Output Normal -ResultPath ./Reports/Pester.xml`
  — this is the exact gate that fails against current state (§3).
- **Tag-guard finding (not a defect, a usage note):** the guard does
  `$tag.TrimStart('v','V')` and compares directly to the manifest's bare `ModuleVersion`
  (`1.0.0`) — it does **not** account for `PrivateData.PSData.Prerelease`. A tag of
  `v1.0.0-alpha1` would **fail** this guard (`'1.0.0-alpha1' -ne '1.0.0'`). When this
  version is eventually tagged, the tag must be `v1.0.0` (prerelease communicated only
  via the manifest's `Prerelease` field / PSGallery prerelease flag, not the git tag
  string), or the guard needs adjustment — routed back rather than changed here, since
  Phase 11 is scoped to leave `.github/workflows/*.yml` untouched.
- `package` job stages only `./POSH-Oceanstor/*` — confirmed (§5 below).
- `sign` job gated behind `vars.SIGNING_ENABLED` (default off — logs `::notice::` and
  re-uploads unsigned).
- `publish` job gated behind `github.ref == 'refs/heads/master'` AND
  `vars.PUBLISH_ENABLED` (default off — always does a dry-run publish to a disposable
  local `LocalDryRun` PSRepository regardless).
- All third-party Actions pinned to a commit SHA.
- Secrets (`SIGNING_CERT_BASE64`, `SIGNING_CERT_PASSWORD`, `PSGALLERY_API_KEY`)
  referenced only via the `secrets:` context — never echoed to logs.

`.github/workflows/powershell.yml` (81 lines, triggers on push/PR to `master` and a
weekly cron):
- `PSScriptAnalyzer` job uses `microsoft/psscriptanalyzer-action` against
  `PSScriptAnalyzerSettings.psd1`, uploading SARIF for code-scanning alerts — this is
  advisory (surfaces findings in the Security tab), not a hard fail-the-build gate.
- `pester-test` job runs `./Tests/Invoke-UnitTests.ps1 -Output Normal -ResultPath
  ./Reports/Pester.xml -CoveragePath ./Reports/Coverage.xml` across a
  `windows-latest`/`ubuntu-latest`/`macos-latest` matrix, without `-FailOnAnalyzerIssue`
  or `-SkipAnalyzer`. Given `Invoke-UnitTests.ps1` throws on any Pester failure
  regardless of that flag, **this job would currently go red on all 3 OS runners** too,
  independent of the analyzer question — the 39 test failures alone fail it.

**CI readiness: not ready.** Both workflows would fail against the current tree; the
gates themselves are sound and require no changes — the code/tests need to reach a
green state first.

## 5. Read-only live validation evidence

No new live-validation run was executed in this phase (network reachability check to
the lab was not attempted from this session; existing same-day evidence was used
instead, consistent with the phase file's allowance to cite/archive existing evidence).

Existing artifact: `Reports/getter-integrity-last-result.md`
- Command (credentials redacted): `Invoke-GetterIntegrityValidation.ps1 -StorageIP 10.10.10.24 -Credential <redacted> -SkipCertificateCheck` (read-only; no mutating switches)
- Run at: 2026-07-07 06:35:02
- Mode: Read-only GET validation; mutation workflows not requested
- Passed = 54, NoData = 11, Skipped = 148, **Blocked = 0**, Failed = 0
- Mutation section: 133 rows, all `NotRequested` (harness correctly collapses opt-in
  mutation checks to `NotRequested` when `-RunMutatingTests` isn't passed)

`Blocked = 0` and no unexpected `SkippedUnsafe`/`NotConfigured` rows beyond the
documented always-off mutation-workflow gates. This satisfies the read-only
live-validation evidence requirement on its own merits, independent of the unit-test
gate outcome above.

## 6. Public documentation safety sweep — PASS

```
grep -rn "10.10.10.24" docs/ README.md   → no matches
find docs -iname "*validation*" -o -iname "*gap-analysis*"   → no matches
```

## 7. Package content safety review — PASS (1 hygiene note, not a blocker)

- `release.yml` `package` job stages only `./POSH-Oceanstor/*` — never `todo/`,
  `.archived-commands/`, `archived-commands/`, `Reports/`, `Tests/`, or `.github/`.
- `.archived-commands/` is `.gitignore`d; one legacy tracked file
  (`system-management-validation-report.md`) predates the ignore rule. It is not staged
  by the package job (which only copies `POSH-Oceanstor/`), so it does not ship via the
  release artifact or `Publish-Module`. Noted as a repo-hygiene cleanup item, not a
  release blocker.

## 8. Mutator safety sweep — PASS

- 205 files with `SupportsShouldProcess`, 169 with `ConfirmImpact` set. The 36-file gap
  is entirely `New-*` (creation) commands plus 3 named exceptions
  (`Add-DMFailoverGroupMember.ps1`, `Set-DMHyperCDPSchedule.ps1`, `Set-DMdnsServer.ps1`)
  — expected: creation carries lower blast radius than removal/failover, so no
  `ConfirmImpact` is an acceptable risk tier here, not a gap.
- Spot-checked actual `ConfirmImpact` values on 14 named DR/network/security/destructive
  commands: all `Remove-*`/`Switch-*`/`Split-*` correctly carry `ConfirmImpact = 'High'`;
  `Set-DMRole`/`Set-DMSnmpUsmUser` correctly carry `ConfirmImpact = 'Medium'` (property
  edits, not destructive removals). No gap found; nothing routed back for this item.

## 9. Carry-over TODOs

- `Oceanstor_PSModule_TODO.md` — reviewed, already comprehensive; no edit needed.
- `docs/network/TODO.md` — reviewed; unsafe-mutator exclusion already documented at
  line 124 (`## Not Planned / Unsafe by Default`); no edit needed.
- `docs/replication-hypermetro/TODO.md` — reviewed; dual-array-lab and
  failover/switchover dedicated-gate requirements already documented (lines 87, 91, 100,
  111); no edit needed.
- `docs/system-management/TODO.md` — **edited**: added a new "High Priority item 3"
  documenting the SNMP USM user analyzer-Error finding (§3a) as an unowned release
  blocker, since it was newly discovered by this phase's gate run and not previously
  recorded anywhere.

## 10. Recommendation

> **SUPERSEDED (Phase 01, 2026-07-07):** items 1–3 below are **DONE** — the 2 SNMP USM
> analyzer errors were cleared (§3a) and the 39 test failures resolved (0 errors / 0
> failures, 1232/1232). The hard gate is now **GO** (see the top of this file). The
> recommendation text below is retained as the original snapshot; only item 4 (tag as
> `v1.0.0`, not `v1.0.0-alpha1`) and the separately tracked signing/publishing/live-mutation
> items (Phases 02/04) remain.

**Do not tag or publish v1.0.0-alpha1 yet.** Before the next go/no-go pass:
1. Fix or explicitly accept the 2 `PSAvoidUsingUsernameAndPasswordParams` analyzer
   errors on the SNMP USM user cmdlets (redesign to `PSCredential`/`SecureString`, or add
   a reviewed suppression with justification — either is a system-management decision,
   not a release-prep one).
2. Resolve or triage the 39 failing tests, at minimum enough to separate "real
   regression" from "stale fixture" from "environment artifact" per the clusters above —
   Cluster H needs no fix, Cluster E is a test-helper assembly-load fix, Clusters A–D and
   F need source-of-truth review against current cmdlet behavior.
3. Re-run `./Tests/Invoke-UnitTests.ps1 -Output Normal` (analyzer enabled, no
   `-SkipAnalyzer`) and confirm 0 errors / 0 failures before scheduling a new go/no-go
   pass.
4. When ready to tag, use `v1.0.0` (not `v1.0.0-alpha1`) to satisfy the release
   workflow's tag-vs-`ModuleVersion` guard (§4).
