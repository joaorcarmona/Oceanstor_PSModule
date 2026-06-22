# Release Notes

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
