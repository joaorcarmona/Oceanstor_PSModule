# Release Notes

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
