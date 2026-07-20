# Release Notes

---

# v1.0.0-beta

Date: 2026-07-07
Branch: `beta-v1.0.0`
Status: Prerelease — not yet tagged/published

## Release Mechanics (read before tagging)

- **Tag convention: use `v1.0.0`, not `v1.0.0-beta`.** `ModuleVersion` in the
  manifest is `1.0.0`; prerelease status is conveyed only by
  `PrivateData.PSData.Prerelease = 'beta'`, never by the git tag. The
  `validate` job in `.github/workflows/release.yml` trims a leading `v`/`V`
  from the tag and compares the result to `ModuleVersion` verbatim — a tag of
  `v1.0.0-beta` fails that guard (`'1.0.0-beta' -ne '1.0.0'`). The guard is
  left as-is (no prerelease-suffix normalization) for this beta; releasers
  must tag `v1.0.0`.
- **Signing: deferred, beta ships unsigned.** No signing certificate has been
  sourced or approved. `vars.SIGNING_ENABLED` remains unset/off, so the `sign`
  job re-uploads the package unsigned and logs a `::notice::`. This is an
  accepted beta limitation, not a defect — see Known Gaps below.
- **Publish: dry-run only, verified.** The `publish` job's dry-run step
  (`Publish-Module` against a disposable local `LocalDryRun` PSRepository,
  registered and unregistered within the job) always runs and does not touch
  the real PowerShell Gallery. The real-publish step is additionally gated on
  `github.ref == 'refs/heads/master'` and `vars.PUBLISH_ENABLED == 'true'` plus
  a present `PSGALLERY_API_KEY` secret; both remain unset/off for this beta,
  so only the disposable local dry-run path is exercised. No real Gallery
  publish has occurred.

## Summary

First beta of the 1.0.0 line, gated by a release-readiness review (Phase 11) of the
post-merge work on `beta-v1.0.0`. This section covers everything confirmed shipped in the
working tree as of this review; unshipped or partially-shipped items are listed under
Known gaps below rather than claimed here.

## New Features

- Added **feature-gated command modules**. The ~314 public commands are now grouped
  into named features (`Host`, `Lun`, `FileSystem`, `Network`, `HyperMetro`,
  `Replication`, `Performance`, …) in `POSH-Oceanstor/DMFeatureMap.psd1`. The two
  data-protection features that cannot be live-validated without a second array or
  quorum — `HyperMetro` and `Replication` — ship **disabled by default**: their
  commands are not exported, so `Get-Command` and tab-completion hide them until the
  feature is enabled. New `Get-DMFeature`, `Enable-DMFeature`, and `Disable-DMFeature`
  cmdlets manage state through a per-user config at
  `%APPDATA%\POSH-Oceanstor\ModuleConfig.json` (only non-default overrides are stored;
  `$env:POSH_OCEANSTOR_CONFIG_PATH` redirects it for labs/CI). Toggling a feature
  requires `Import-Module POSH-Oceanstor -Force` to take effect. Import always fails
  open — a missing, malformed, or unknown-key config falls back to built-in defaults
  with a warning rather than blocking module load — and a Pester suite enforces that
  every exported command is assigned to exactly one feature.
- Added `Set-DMMappingView` and `Rename-DMMappingView` for editing a mapping
  view's name and description (REST `PUT /mappingview/{id}`). Only the
  `NAME`/`DESCRIPTION` labels change; host-group, LUN-group, and port-group
  associations are never touched (use `Add-`/`Remove-DM*ToMappingView` for
  those). Both are `SupportsShouldProcess` with `ConfirmImpact = 'High'` because
  a mapping view is an access-path object. The live mapping workflow gained a
  test-owned `Set-DMMappingView` description read-back.
- Added SAN remote replication and HyperMetro command families for Dorado 6.1.6:
  remote devices/LUNs, replication pairs, replication consistency groups,
  HyperMetro domains, HyperMetro pairs, and HyperMetro consistency groups.
  Domain lifecycle commands cover create, modify, delete, and quorum-server
  association, while pair and group lifecycle commands cover create, modify,
  delete, synchronize, split/suspend/start, switchover/priority-switch
  operations, and group pair-association operations.
- Added opt-in live integration workflow scaffolding for remote replication and
  HyperMetro. The workflows are disabled by default and require explicit
  lab-only remote device, remote LUN, domain, and DR mutation settings in
  `Tests/Integration/IntegrityValidationConfig.psd1`; failover/priority-switch
  steps have separate safety switches.
- Added NAS/vStore DR wrappers for vStore pairs, file-system replication pair
  creation and file-specific secondary-protection operations, and file-system
  HyperMetro domain get/create/remove/start/join/split/switch operations. These
  wrappers use distinct names such as `Get-DMVStorePair`,
  `New-DMFileSystemReplicationPair`, and `Get-DMFileHyperMetroDomain` so SAN
  LUN workflows and NAS/vStore workflows remain explicit.
- Added `Get-DMCertificate` for reading array certificate objects.
- Added `Get-DMQuorumServer` for reading HyperMetro quorum server configuration.
- Added `Get-DMFailoverGroupMember` (alias `Get-DMFailoverGroupMembers`) for
  reading the member list of a network failover group.
- `Get-DMAlarm` now supports `-StartTime`/`-EndTime` and a `-Last` timespan
  filter for narrowing alarm queries by date range, converting to Unix-epoch
  bounds for the underlying request. `-Last` and an explicit
  `-StartTime`/`-EndTime` pair are mutually exclusive.

## Performance Improvements

- Added non-secure HyperCDP schedule management with
  `Get/New/Set/Remove/Enable/Disable-DMHyperCDPSchedule` plus
  `Add/Remove-DMLun*HyperCDPSchedule` LUN association commands. The live
  integrity workflow can validate schedule create/read/update/LUN
  associate/remove/enable/disable/delete without using protection groups or
  secure snapshots.
- Optimized `Get-DMhost` host initiator enrichment. Host objects still expose
  their `initiators` array, but `Set-DMHostInitiator` now bulk-loads all Fibre
  Channel and iSCSI initiators once and groups them by host ID instead of making
  two initiator lookups per host. On the validation array, retrieving 215 hosts
  dropped from about 33 seconds to about 1 second.
- Adjusted `Get-DMhost` parameter positions so the host name remains the
  positional argument while `WebSession` binds by pipeline/property name.
- Removed positional binding from public `WebSession` parameters across the
  module and shifted user-facing positional arguments down accordingly, so calls
  like `Get-DMhostGroup Name`, `Get-DMlunByName Name`, and
  `New-DMFileSystem Name PoolId` bind to resource parameters instead of the
  session parameter.
- Reduced the default duration of mutating integrity validation by making the
  expensive multi-LUN pipeline batch regression workflow opt-in via
  `LunGroup.EnablePipelineBatchCoverage`. Integrity Markdown reports now include
  a `Slowest Checks` section to make runtime hot spots visible.
- Optimized `Set-DMLun` and `Rename-DMLun` resolution paths. Both commands now
  support `-LunId`, and `Set-DMLun` uses filtered `Get-DMlun -Name/-Id` lookups
  instead of loading the full LUN inventory before every modification.
- Optimized `Remove-DMLun` resolution paths. The command now supports `-LunId`
  and uses filtered `Get-DMlun -Name/-Id` lookups instead of loading the full
  LUN inventory before deleting one LUN.
- Optimized `New-DMLunSnapshot` source LUN resolution and adjacent snapshot
  checks. Source LUN name paths now use filtered `Get-DMlun -Name` lookups, the
  integrity workflow creates snapshots with the known LUN ID, and
  `Get-DMLunSnapshot -Name` now narrows requests server-side.
- Optimized LUN membership and protection-group association commands. LUN name
  paths in `Remove-DMLunFromLunGroup`, `Add-DMLunToProtectionGroup`,
  `Remove-DMLunFromProtectionGroup`, and `Get-DMProtectionGroup -LunName` now
  use filtered LUN lookups, and LUN-group removal checks membership without
  materializing the full LUN inventory.
- Optimized integrity validation hot spots above two seconds by replacing broad
  LUN, LUN-group, file-system, protection-group, and consistency-group readbacks
  with filtered lookups where the workflow already knows the target name or ID.
  `Get-DMlun -LunGroup`, `-LunGroupName`, and `-LunGroupId` now resolve group
  member IDs directly instead of loading every LUN before filtering locally.
- Optimized LUN snapshot name paths. `Get-DMLunSnapshot -LunName` now resolves
  the source LUN with a filtered lookup, and LUN snapshot action/copy commands
  use `Get-DMLunSnapshot -Name` instead of loading every snapshot before
  filtering by name.
- Added a `-RunPipelineBatchCoverage` integration-runner switch for the
  expensive multi-LUN pipeline regression workflow. The workflow now reports
  `New-DMLun:PipelineBatch` as a real mutation step, uses filtered read-backs,
  verifies LUN-group removal, and keeps ID-based cleanup for generated LUNs
  when the array returns IDs.

## Bug Fixes

- Fixed `New-DMLunSnapshot` pipeline input so LUN objects from `Get-DMlun` bind
  as source LUNs instead of being mistaken for the `WebSession` parameter.
- Made `New-DMLunSnapshot -SnapshotName` optional and allowed an empty value.
  When omitted or blank, the command now generates
  `<LunName>_SNAP_<compact UTC tick serial>`.

## Output Improvements

- Clarified LUN capacity output units by adding `Lun Size (GB)` and
  `Lun Used Capacity (GB)` properties to both v3 and v6 LUN model classes.
  `Get-DMlun` default output, the LUN format view, and LUN report templates now
  use the explicit `(GB)` property names. The previous `Lun Size` and
  `Lun Used Capacity` properties remain populated as compatibility aliases.
- Confirmed file-system capacity output already uses the explicit
  `Capacity (GB)` property and default display name.

## Breaking Changes

- `Get-DMdnsServer` now returns typed `OceanStorDnsServer` objects instead of
  a raw hashtable/string. Scripts that indexed the previous output as a
  hashtable or parsed it as a string must switch to property access
  (e.g. `$result.Address`) against the new type.

## Testing / Validation

- Added a `SystemManagement` mutation workflow
  (`Tests/Integration/Private/Workflows/SystemManagement.ps1`) to the live
  integrity harness.
- Added a `DMResponseFixtures` mock-response fixture library
  (`Tests/Unit/Support/DMResponseFixtures.ps1` + tests) and an
  `Assert-DMWhatIfSafe` unit-test helper for asserting mutators don't call
  through when `-WhatIf` is set.
- The live integrity report correctly labels opt-in mutation checks as
  `NotRequested` when `-RunMutatingTests` is not passed, per the harness
  semantics established for the report format.
- Unit test suite result (2026-07-07 release-gate run, analyzer enabled):
  **1232 passed, 0 failed** (1232 total). PSScriptAnalyzer: **0 Error-severity
  findings** (93 Warning / 24 Information remain, tracked as deferred cleanup and
  non-blocking). Both gate forms — `./Tests/Invoke-UnitTests.ps1 -Output Normal`
  and the release gate `-FailOnAnalyzerIssue -Output Normal` — now pass. The 39
  failures recorded at the Phase 11 go/no-go were resolved by subsequent merges;
  Phase 01 verified them green and hardened two environment-sensitive spots
  (see below).
- **SNMP USM analyzer decision (Phase 01):** the 2 `Error`-severity
  `PSAvoidUsingUsernameAndPasswordParams` findings on `New-DMSnmpUsmUser.ps1`
  and `Set-DMSnmpUsmUser.ps1` were resolved by a **narrow, justified
  `[SuppressMessageAttribute]`** rather than a parameter redesign. SNMPv3 USM
  uses two separate passphrases (auth + privacy) plus a user name, which cannot
  be expressed as a single `[PSCredential]`; `[SecureString]` input is already
  accepted and secrets are never printed or logged, so no public-contract change
  was made (the documented plaintext-or-SecureString behavior is preserved).
- **Release-gate hardening (Phase 01):** the analyzer step in
  `Tests/Invoke-UnitTests.ps1` now retries transient PSScriptAnalyzer engine
  faults (intermittent `NullReferenceException` / dynamic-assembly races on cold
  start) so the gate is deterministic, and `-FailOnAnalyzerIssue` now blocks only
  on `Error`-severity findings (matching the documented go/no-go gate intent).
  `Import-DMPerformanceReportCsv` and its test now `Add-Type` the
  `System.IO.Compression.FileSystem` assembly so `[System.IO.Compression.ZipFile]`
  resolves on Windows PowerShell 5.1 as well as PowerShell 7+.

## Safety

- `Set-DMLLDPWorkingMode` and related network-topology mutators
  (`Set-DMLif`, failover-group/vLAN mutators) now declare
  `ConfirmImpact = 'High'` in addition to `SupportsShouldProcess`.
- Added `.github/workflows/release.yml`, a release pipeline that packages the
  module, gates Authenticode signing behind `SIGNING_ENABLED` (off by
  default), and gates PowerShell Gallery publish behind `PUBLISH_ENABLED` +
  a configured API key secret, with an unconfigured-publish path that fails
  loudly instead of publishing silently.
- **This package is unsigned.** The signing-certificate decision referenced
  above is still open; this prerelease ships without Authenticode signing.

## Known Gaps / Carried Forward

- Signing-certificate acquisition/decision is still open — tracked for a
  future cycle before a signed release can ship.
- Network- and system-management-domain mutators considered unsafe for
  unattended live validation remain intentionally excluded from the
  integrity harness (`SkippedUnsafe`), not exercised end-to-end by the
  automated report.
- NAS/vStore DR workflows (file-system HyperMetro, vStore pair failover)
  need a dual-array lab to validate live; not exercised in this cycle's
  report.
- Failover/switchover operations (HyperMetro pair switchover, DR failover)
  need dedicated, explicitly-gated per-operation validation before they can
  be considered release-verified; currently opt-in and unexercised.

---

# v0.9.5

Date: 2026-07-01
Branch: `fix/analysis-findings`
Status: Released to `master`

## Summary

This release is a focused hardening pass driven by a systematic analysis of the
module's security, reliability, and correctness surface (`ANALYSIS.md`). It
closes 14 open findings across five categories: security, correctness, reliability,
performance, and code quality.

## Security Fixes

- **S1 — Certificate validation opt-in:** `-SkipCertificateCheck` on
  `Connect-deviceManager` is now opt-in; the integration test runner forwards
  the flag correctly.
- **S2 — Credential wipe:** Plaintext password and username variables are
  cleared from memory immediately after the login call returns.
- **S3 — Session auth header cleanup:** The `Authorization: Basic …` header is
  removed from the session after login; all subsequent calls authenticate with
  `iBaseToken` only, so the Base64-encoded credential is not sent with every
  REST request.
- **S4 — URI encoding:** Every user-supplied value interpolated into a REST
  query string is now wrapped with `[uri]::EscapeDataString()` across five
  commands (`Get-DMhostbyName`, `Get-DMhostbyId`, `Get-DMlunByWWN`,
  `Get-DMLunsbyFilter`, `Remove-DMFiberChannelInitiator`), preventing callers
  from injecting characters that alter the OceanStor filter expression.
- **S5 — Redundant credential copy removed:** The `hidden [string]$iBaseToken`
  field on `OceanstorSession` was written in the constructor but never read by
  any production code. The field and its assignment have been removed, reducing
  the token's in-memory footprint.

## Correctness Fixes

- **C1 — Null-dereference after `@(...)[0]`:** Added an explicit null-check
  guard immediately after every body-level `$var = @(...)[0]` dereference
  across 51 Public commands (70 insertion points). A clear `throw` now fires
  before any property access reaches the API instead of silently sending a
  malformed resource path.
- **C2 / C3 — `OceanstorLunv6` class fixes:** Corrected the inverted
  `WorkloadTypeName` branch (LUNs with a workload type were showing `"invalid"`;
  those without were reading from an empty field). Fixed `Rename()` so
  `$this.Name` is updated to reflect the new name after a successful call.
- **C4 — Null session guard:** Added a guard inside `Invoke-DeviceManager` that
  throws `"No OceanStor session available. Call Connect-deviceManager first"` when
  neither `-WebSession` nor the global `$deviceManager` is set, replacing a
  cryptic null-property error.
- **C5 — API error surfacing on GET commands:** Added private helper
  `Select-DMResponseData` that checks `error.Code` before returning `.data`,
  throwing a descriptive `"OceanStor API error N: …"` message on non-zero codes.
  Replaced all 38 occurrences of `| Select-Object -ExpandProperty data` in
  Public `Get-DM*` commands and `Remove-DMPortFromPortGroup`.
- **C6 — Session leak on reconnect:** `Connect-deviceManager` now calls
  `Disconnect-deviceManager` on the existing global session (best-effort, with
  `Write-Warning` on failure) before overwriting it, preventing orphaned
  authenticated sessions on the array.
- **C7 — Pre-flight mapping check:** `Remove-DMLun` now throws before issuing
  the DELETE call when the LUN is currently mapped to a host, surfacing a clear
  error instead of letting the API reject the request with a generic code.
- **C8 — Redundant API round-trips:** `Add-DMHostToHostGroup`,
  `Remove-DMHostFromHostGroup`, and `Add-DMPortToPortGroup` now cache the
  `Get-DM*` result from `ValidateScript` in a `$script:`-scoped variable and
  reuse it in the function body, eliminating the duplicate lookup that previously
  fired once for validation and once for execution.
- **C9 — Deterministic bracket-strip fallback:** `Get-DMlunbyLunGroup` now
  uses `TrimStart('[').TrimEnd(']')` in its `ConvertFrom-Json` fallback path
  instead of a fragile regex, preventing a silent empty-result when the API
  returns a non-standard format.

## Quality Improvements

- **Q1 — `New-DMFileSystem` positional parameters:** Fixed incorrect positional
  parameter ordering that caused capacity to be read from the wrong binding.
- **Q3 — vStore scope leak:** `Get-DMhost`, `Get-DMhostGroup`, and
  `Get-DMlunGroup` now accept a `-VstoreId` parameter (appended as
  `?vstoreId=X` to the resource URL). `Set-DMHost`, `Set-DMHostGroup`, and
  `Set-DMLunGroup` forward their `-VstoreId` to the inner getter call,
  preventing cross-vStore object resolution.
- **Q4 — Capacity parsing consolidation:** Replaced the ~44-line inline capacity
  parsing blocks in `New-DMLun` and `New-DMFileSystem` with calls to the
  existing `ConvertTo-DMCapacityBlock` private helper, eliminating the
  maintenance split between three copies of the same logic.
- **Q5 — `Set-DMLun` return type alignment:** `Set-DMLun` now returns a single
  `PSCustomObject` (`$response.error`) matching every other `Set-DM*` command,
  eliminating the `List[object]` that required callers to use a different code
  path.
- **Q6 / Q7 — `Set-DMdnsServer` / `Get-DMdnsServer` cleanup:** `Set-DMdnsServer`
  now returns `$response.error` (was returning a `Hashtable` or `[string]`);
  the unconditional read-back call was removed. `Get-DMdnsServer` replaces
  manual bracket-stripping with `ConvertFrom-Json`.
- **Q9 — Pagination:** `Get-DMlun`, `Get-DMFileSystem`, and other collection
  commands route through `Invoke-DMPagedRequest` to retrieve all pages from the
  OceanStor API instead of truncating at the default page size.

## Test Suite

- 409 unit tests — 0 failures.
- 10 affected test modules updated to dot-source `Select-DMResponseData`.
- Integration test private-helper allow-list updated to include
  `Select-DMResponseData`.
- New test files added for `Remove-DMLun`, `Add-DMHostToHostGroup`,
  `Remove-DMHostFromHostGroup`, `Add-DMPortToPortGroup`,
  `Get-DMlunbyLunGroup`, `Get-DMhost`, `Get-DMhostGroup`, and `Get-DMlunGroup`.

## Commit History

- `578028d` - fix(Q5): Set-DMLun returns single PSCustomObject
- `c0e04d7` - fix: add Select-DMResponseData to integration test allow-list
- `cf693b2` - fix(C5): replace Select-Object -ExpandProperty data with error-aware helper
- `2b8029c` - fix(S4,C1): URI-encode user input in REST paths; remove misplaced null guards
- `18d2f96` - fix(C1): add null-check guards after every @(...)[0] dereference
- `fbc348b` - refactor(Q4): replace inline capacity parsing with ConvertTo-DMCapacityBlock
- `5874d88` - fix(Q3): forward VstoreId through getter commands
- `f570da9` - fix(C9): deterministic bracket-strip fallback in Get-DMlunbyLunGroup
- `ac5be5f` - perf(C8): eliminate redundant API round-trips in membership commands
- `85c3d45` - fix(C7): pre-flight mapped-LUN check in Remove-DMLun
- `ed32ec9` - fix(S5): remove redundant plaintext iBaseToken field
- `34551fd` - fix(S3): remove Basic Auth header from post-login session
- `40d2201` - fix(S2): wipe plaintext credentials from memory after login
- `1c1ceba` - fix(S1): make certificate validation opt-in
- `2a516c7` - fix(C4,C5,C6): session null guard, error surfacing, session-leak on reconnect
- `ffe8319` - fix(Q6,Q7): align Set-DMdnsServer return type and harden Get-DMdnsServer
- `89e9f18` - feat(Q9): add pagination to Get-DM* collection commands
- `e8719d1` - fix(Q1): correct New-DMFileSystem parameter positions
- `b1d00f2` - fix(C2,C3): correct OceanstorLunv6 Rename() and WorkloadType mapping

---

# v0.9.4

Date: 2026-06-23
Branch: `todo-v0.9.3`
Status: Released to `master`

## Summary

This release renames 30 plural-noun getter commands to their singular canonical
forms and exports backward-compatibility aliases for all renamed commands, adds
`Disconnect-deviceManager` for explicit session teardown, standardizes
state-modifying commands with `-PassThru` and full `ShouldProcess` support,
enforces the full PSScriptAnalyzer rule set with all false positives suppressed,
and upgrades the CI pipeline with cross-platform testing and code coverage.

## Changes

- Added `Disconnect-deviceManager` for explicit session teardown: issues the
  DELETE call, removes global session state, and guards against double-disconnect.
- Renamed 30 plural-noun getter commands to singular (e.g. `Get-DMLuns` →
  `Get-DMLun`) and exported 30 backward-compatibility aliases so existing
  scripts continue to work without modification.
- Replaced the `-Return [boolean]` convention with a standard `-PassThru
  [switch]` on state-modifying commands that can return the modified object.
- Added `ShouldProcess` support (`-WhatIf` / `-Confirm`) to all state-changing
  public commands.
- Replaced wildcard module exports with an explicit function list in the
  manifest, making the exported surface intentional and auditable.
- Pushed LUN filter queries server-side in `Get-DMLun` and tightened its
  parameter types.
- Renamed three private helpers to use the approved `Test-` verb:
  `Validate-Ipv4Address` → `Test-IPv4Address`,
  `Validate-WWNAddress` → `Test-WWNAddress`, and
  `Validate-ModuleRequirements` → `Test-ModuleRequirements`.
- Renamed three additional private helper files to singular nouns for
  consistency.
- Fixed a misspelled `Activacate()` method in the session class.
- Fixed `$matches` variable shadowing PowerShell's automatic `$Matches`.
- Replaced `Write-Host` with `Write-Warning` throughout the module source.
- Fixed a literal hashtable initialization issue in `Set-DMdnsServer`.
- Replaced `exit` with `throw` to prevent unintended PSSession termination.
- Removed dead Kerberos parameters from `New-DMnfsClient`.
- Suppressed justified PSScriptAnalyzer false positives across 63 functions and
  class files; upgraded CI to run the full rule set.
- Upgraded CI with a cross-platform test matrix (Windows, Ubuntu, macOS),
  Pester code coverage upload, and a `.psscriptanalyzerrc` settings file.
- Added `.gitattributes` to normalize line endings across platforms.
- Added README badges: license, release, PowerShell version, and last commit.
- Completed help documentation for all `Set-DM*` and `Rename-DM*` commands.
- Added inline documentation and `[OutputType([long])]` to
  `ConvertTo-DMCapacityBlock`.
- Expanded the unit suite to 312 passing tests.

## Commit History

- `da81536` - Add inline documentation to ConvertTo-DMCapacityBlock
- `656966e` - Revert cross-platform CI matrix to Windows-only
- `02c16fb` - Fix case-sensitive path and class resolution for Linux/macOS CI
- `85a37b6` - Fix cross-platform test failures for Connect and Disconnect
- `6c3fa68` - Fix OceanstorSession class preload in test modules
- `fafe87d` - Bump module version to 0.9.4
- `3b456fb` - Complete help documentation for Set and Rename commands
- `6db07d8` - Add license, release, PowerShell, and last-commit badges to README
- `542cd60` - Add cross-platform test matrix (Windows, Ubuntu, macOS)
- `0832a3a` - Export 30 backward-compatibility aliases in module manifest
- `386416c` - Fix OceanstorSession class load order
- `cdbb80c` - Add .gitattributes to normalize line endings
- `58f574c` - Add CI status badge to README
- `64bd51e` - Add PSScriptAnalyzer settings file to exclude pipeline rule
- `9ef09c8` - Add Pester code coverage to CI workflow
- `04087ee` - Suppress PSAvoidGlobalVars for intentional module-level state
- `9ef5f12` - Suppress PSAvoidUsingPlainTextForPassword on ChapPassword
- `aeac9dc` - Remove dead Kerberos parameters from New-DMnfsClient
- `20a5402` - Rename `$matches` variable to avoid shadowing automatic variable
- `b9bc640` - Fix literal hashtable initializer in Set-DMdnsServer
- `85a8877` - Replace Write-Host with Write-Warning in module source
- `b7c336d` - Suppress false-positive PSReviewUnusedParameter in 63 functions
- `15baf6a` - Suppress false-positive PSAvoidUsingCmdletAliases in class files
- `10665cd` - Add ShouldProcess support to all state-changing commands
- `80b872e` - Rename 3 private helpers to singular nouns
- `5540ab9` - Run full PSScriptAnalyzer rule set in CI
- `50e2e23` - Add unit tests for Disconnect, NFS creation, and DNS commands
- `9afc362` - Remove misspelled Activacate() method
- `90923d1` - Update documentation for singular-noun and PassThru renames
- `d54a9b1` - Rename 30 plural-noun getter commands to singular
- `f88ee9f` - Replace -Return [boolean] with -PassThru [switch]
- `ef23962` - Rename Validate- private helpers to approved Test- verb
- `7ef6831` - Push LUN filter queries server-side and tighten parameter types
- `7c3902b` - Replace wildcard exports with explicit function list in manifest
- `b6ad41e` - Add Disconnect-deviceManager and session cleanup guard
- `0b04544` - Replace exit with throw to prevent session termination

## Highlights

- Added `Disconnect-deviceManager`, a new public command that explicitly
  closes the DeviceManager session by issuing a DELETE request, clearing the
  global session variable, and guarding against re-entry if the session is
  already gone.
- Renamed 30 plural-noun getter commands to their singular canonical forms
  (`Get-DMLuns` → `Get-DMLun`, `Get-DMHosts` → `Get-DMHost`, etc.) to conform
  to the PowerShell noun-singular naming convention. All 30 renamed commands
  retain backward-compatibility aliases in the module manifest so existing
  scripts continue to work without modification.
- Replaced the project-specific `-Return [boolean]` pattern with the standard
  PowerShell `-PassThru [switch]` on all state-modifying commands that can emit
  the modified storage object.
- Added `ShouldProcess` support to all state-changing commands, enabling
  `-WhatIf` and `-Confirm` on `New-DM*`, `Set-DM*`, `Rename-DM*`, and
  `Remove-DM*` commands.
- Replaced wildcard exports (`FunctionsToExport = '*'`) with a full explicit
  function list in the module manifest.
- Renamed three private helpers from the non-standard `Validate-` verb prefix
  to the approved `Test-` verb: `Test-IPv4Address`, `Test-WWNAddress`, and
  `Test-ModuleRequirements`.
- Enforced the full PSScriptAnalyzer rule set in CI, audited every finding, and
  suppressed all justified false positives with
  `[Diagnostics.CodeAnalysis.SuppressMessageAttribute]` annotations across
  63 functions and the class files.
- Upgraded the CI workflow with a cross-platform test matrix covering Windows,
  Ubuntu, and macOS, Pester code coverage upload, and a `.psscriptanalyzerrc`
  settings file to configure the pipeline-input rule. The cross-platform matrix
  was subsequently reverted to Windows-only due to class-loading differences on
  non-Windows platforms.
- Added `.gitattributes` to enforce consistent LF line endings across platforms.
- Updated the module manifest version to `0.9.4`.

## Validation

- Unit tests: 312 passed, 0 failed (14 new tests added for `Disconnect-deviceManager`,
  `New-DMnfsShare`, `New-DMnfsClient`, and `Set-DMdnsServer`).
- PSScriptAnalyzer: zero findings under the full rule set after justified
  suppressions.
- Backward-compatibility aliases: 30 plural-noun aliases exported and verified.
- Parser validation: changed PowerShell scripts parsed successfully.
- Diff validation: staged whitespace checks passed before commit.

---

# v0.9.3

Date: 2026-06-23
Branch: `v0.9.3`
Status: Released to `master`

## Summary

This release builds on `v0.9.2` with documentation and usability cleanup for
the public command surface. It completes public command help coverage,
standardizes initiator parameter spelling, clarifies report-template usage,
updates WebSession wording, and removes stale per-command metadata from
comment-based help.

## Maintenance Update — 2026-06-22

- Added human-readable `MB`, `GB`, and `TB` capacity input for LUN and file-system creation, including period and comma decimal separators.
- Added `Set-DMLun` and `Set-DMFileSystem` with first-class rename and resize operations, additional Huawei API property passthrough, and `WhatIf`/confirmation support.
- Added `Set-DMHost`, `Set-DMHostGroup`, `Set-DMLunGroup`, and `Set-DMPortGroup` for safe named-object modification.
- Added focused `Rename-DM*` commands for LUNs, file systems, hosts, host groups, LUN groups, and port groups.
- Added `Expand()` and `Rename()` methods to the corresponding storage object classes. LUN modification remains restricted to Dorado V6 sessions.
- Added shared capacity and named-object validation helpers, duplicate-name protection, and vStore-aware modification resources.
- Removed generated pipeline report artifacts from version control and added them to `.gitignore`.
- Expanded the unit suite to 295 passing tests with no failures.

## Commit History

- `1d8f7e6` - Update WebSession naming and docs
- `223deb3` - Complete public command help coverage
- `bd405ed` - Clarify report template customization
- `0af4963` - Standardize `InitiatorType` parameter spelling
- `96a6504` - Simplify public command notes metadata
- `c75545a` - Prepare v0.9.3 release notes
- `ac5fd8a` - Update manifest copyright year
- `d9d548e` - Add storage modification and rename workflows
- `cb9a00e` - Validate Set and Rename mutation workflows

## Highlights

- Completed required help sections for public commands, including descriptions,
  parameter help, inputs, outputs, examples, and notes.
- Standardized `Get-DMHostInitiators` on the correctly spelled
  `InitiatorType` parameter and removed the compatibility alias for the old
  `InitatorType` spelling.
- Updated FC and iSCSI initiator wrapper commands, removal commands,
  integration validation, and unit tests to use the corrected parameter name.
- Clarified how report templates are discovered and customized in
  `POSH-Oceanstor/Templates/README.md`.
- Renamed `REport-Lunsv6.xml` to `Report-Lunsv6.xml`.
- Improved `about_POSH-Oceanstor` with module overview, usage, authentication,
  command areas, reporting, safety guidance, and related links.
- Updated WebSession documentation and examples for consistent casing and
  wording.
- Removed stale `Author`, `Modified Date` / `Modfied Date`, and `Version`
  entries from public command `.NOTES` sections, keeping only `Filename`
  metadata.
- Updated the module manifest version to `0.9.3`.

## Validation

- Unit tests: 295 passed, 0 failed.
- Public command metadata validation: `Get-DMHostInitiators` exposes
  `InitiatorType` only, with no typo alias.
- Typo scan: no `InitatorType` or `initatorType` references remain.
- Public help metadata scan: no stale `.NOTES` fields remain in public command
  files.
- Parser validation: changed PowerShell scripts parsed successfully.
- Diff validation: staged whitespace checks passed before commit.

---

# v0.9.2

Date: 2026-05-30
Branch: `v0.9.2`

## Summary

This release reorganizes the live OceanStor integration validator into focused
workflow scripts, documents the complete test methodology, and adds an XML test
execution plan with priorities and dependencies. It also fixes integration
coverage reporting discovered during a full create, verify, and cleanup run,
and normalizes PowerShell verb capitalization throughout the project.

## Commit History

- `23686a0` - Prepare v0.9.2 integration test workflows and documentation
- `cde6aaa` - Normalize PowerShell verb capitalization for v0.9.2

## Highlights

- Split the live integration validator into reusable helper, read-validation,
  mutation-orchestration, reporting, and workflow scripts.
- Kept `Invoke-GetterIntegrityValidation.ps1` as the small public entry point.
- Added `Tests/TestExecutionOrder.xml` with unit-suite priorities and live
  integration dependencies.
- Added `Tests/README.md` with unit, read-only integration, mutation integration,
  custom configuration, and report-retention examples.
- Fixed coverage reporting for `Verify:` mutation read-back checks.
- Added host-group association read-back validation by both ID and name.
- Ignored generated `mutation-trace-last-result.json` output.
- Normalized PowerShell verb capitalization in public commands, private
  helpers, tests, documentation, and XML execution metadata.
- Renamed command and test files so standard verbs consistently use their
  canonical capitalization, including `Get-*`, `New-*`, and `Remove-*`.
- Corrected the exported `Get-DMbbus` function declaration capitalization.
- Updated the module manifest version to `0.9.2`.

## Validation

- Unit tests: 239 passed, 0 failed.
- Read-only integration validation: 34 passed, 14 valid no-data results,
  0 failed.
- Full mutation integration validation: 110 passed, 14 valid no-data results,
  0 blocked, 0 failed.
- Mutation trace: 670 requests recorded.
- Cleanup verification: 0 remaining test-owned resources.
- PowerShell parser validation: all 214 PowerShell files parsed successfully.
- Export validation: all 114 module commands use canonical verb
  capitalization.
- XML execution plan validation: 162 tests listed with no duplicate orders.

---

# Release Notes - v0.9.1

Date: 2026-05-25
Branch: `v0.9.1`

## Summary

This release improves code readability and formatting across the public
commands, hardens connection credential handling, adds validation and
completion for selected storage-object parameters, updates connection
documentation, and introduces PSDepend dependency declarations.

## Changes

- `bd43c31` - code read improvement
- `d3d4f02` - Improve code formating
- `3a14054` - Improve security accordingly with PSScriptAnalyzer
  - Added parameter validation and autocomplete to some functions.
  - Correct README.md to reflect the new connection method.
- `5fb7751` - Added Dependencies
  - Fix Manifest to reflect PowerShell version requirement.

## Highlights

- Reformatted public commands using the shared `CodeFormatting.psd1` rules,
  including multiline formatting for statement block contents.
- Updated `Connect-deviceManager` to accept secure credential paths for
  interactive and unattended operation.
- Added parameter validation and argument completion for selected mapping,
  file-system, dTree, and NFS operations.
- Updated README connection examples to use secure credentials rather than a
  plaintext password.
- Added `requirements.psd1` for `ImportExcel`, `Pester`, and
  `PSScriptAnalyzer` dependencies through PSDepend.
- Updated the module manifest to require PowerShell 6.0 or higher.
- Ignored generated mutation trace output from integration validation.

## Validation

- Unit tests: 239 passed, 0 failed.
- PSScriptAnalyzer: no findings in changed public scripts.

---

# Release Notes - Unit Tests and Display Improvements

Date: 2026-05-24
Proposed branch: `unit-files`

## Summary

This update introduces broad Pester coverage for the POSH-Oceanstor module,
adds a repeatable test runner and read-only live validation workflow, fixes
several defects found during testing, and improves default console output for
public getter commands.

## Test Coverage

- Added private function tests under `Tests/Unit/Private`.
- Added model class coverage for core, hardware, host, storage, session, and
  view classes.
- Added public command coverage for connection, getter, and export functions.
- Added `Tests/Invoke-UnitTests.ps1` to run the complete unit suite and
  optionally write an NUnit XML report.
- Added `Tests/Integration/Invoke-GetterIntegrityValidation.ps1` for
  credential-prompted, read-only validation against a real storage system.

## Defect Fixes

- Corrected CRLF parsing in `Get-DMparsedElabel`.
- Corrected explicit XML template handling in `New-DMObjectReport`.
- Corrected mapped class property assignments for vStores, workloads, host
  groups, and port models.
- Corrected host group filtering to use the mapped parent properties.
- Changed FC and iSCSI initiator `vStore ID` to `Int64` so the API value
  `4294967295` is accepted without overflow.
- Removed stray console debug output from `Export-DMStorageToExcel`.

## LUN Creation Enhancements

- Added `New-DMLun` for REST-based LUN creation with configurable allocation,
  caching, compression, deduplication, SmartTier, and workload options.
- Added storage pool validation and interactive argument completion based on
  currently available storage pools.

## Output Improvements

- Added compact default property displays to object-producing `Get-*`
  commands so interactive output shows the most operationally relevant
  fields while complete object properties remain available.
- Updated array construction in the affected getters to use
  `ArrayList.Add()` instead of repeated array concatenation.
- Kept `Get-DMdnsServer` unchanged because it already returns a compact
  key/value map rather than model objects.

## Validation

- Unit tests: 98 passed, 0 failed.
- Live read-only getter validation was run against the test storage endpoint;
  after the initiator identifier fix it completed with 35 successful checks,
  4 valid no-data results, and 0 failures.

## Notes

- The live validation result JSON is generated locally and is not intended to
  be committed as a release artifact.
