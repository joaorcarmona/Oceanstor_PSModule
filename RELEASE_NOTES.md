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
- Updated `connect-deviceManager` to accept secure credential paths for
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

- Corrected CRLF parsing in `get-DMparsedElabel`.
- Corrected explicit XML template handling in `new-DMObjectReport`.
- Corrected mapped class property assignments for vStores, workloads, host
  groups, and port models.
- Corrected host group filtering to use the mapped parent properties.
- Changed FC and iSCSI initiator `vStore ID` to `Int64` so the API value
  `4294967295` is accepted without overflow.
- Removed stray console debug output from `export-DMStorageToExcel`.

## LUN Creation Enhancements

- Added `new-DMLun` for REST-based LUN creation with configurable allocation,
  caching, compression, deduplication, SmartTier, and workload options.
- Added storage pool validation and interactive argument completion based on
  currently available storage pools.

## Output Improvements

- Added compact default property displays to object-producing `get-*`
  commands so interactive output shows the most operationally relevant
  fields while complete object properties remain available.
- Updated array construction in the affected getters to use
  `ArrayList.Add()` instead of repeated array concatenation.
- Kept `get-DMdnsServer` unchanged because it already returns a compact
  key/value map rather than model objects.

## Validation

- Unit tests: 98 passed, 0 failed.
- Live read-only getter validation was run against the test storage endpoint;
  after the initiator identifier fix it completed with 35 successful checks,
  4 valid no-data results, and 0 failures.

## Notes

- The live validation result JSON is generated locally and is not intended to
  be committed as a release artifact.
