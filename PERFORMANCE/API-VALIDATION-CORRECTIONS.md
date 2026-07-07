# Performance API Validation Corrections

## Summary

This note records the implementation follow-up from `API-VALIDATION-FAILURES.md`. No live storage commands were run for these corrections.

## Changes Implemented

- Added `Export-DMStorageToExcel -PerformanceLunLimit`.
- Changed Excel performance export so large LUN collections are no longer skipped wholesale by the 500-object safety cap.
- Added unit tests for the 31-character report-task name limit.
- Updated unit tests for Excel LUN performance limiting.
- Kept metric applicability as documentation-only caveats; no strict metric blocking was added.

## Excel LUN Performance Export Behavior

`Export-DMStorageToExcel -IncludeObject performance` now samples at most the first 25 LUNs from the supplied storage inventory by default.

Use `-PerformanceLunLimit` to increase the limit:

```powershell
Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -PerformanceLunLimit 100 -ReportFile .\storage-performance.xlsx
```

Set `-PerformanceLunLimit 0` for no LUN limit:

```powershell
Export-DMStorageToExcel -OceanStor $storage -IncludeObject performance -PerformanceLunLimit 0 -ReportFile .\storage-performance.xlsx
```

The default is first-N, not true top-N. Ranking the top busy LUNs would require sampling all LUNs first, which is not safe as a default Excel export behavior on large arrays. Use `Get-DMLunPerformance` directly for true top-busy analysis.

## Documentation Caveats Added

The documentation describes:

- `QueueLength` can be `$null` on `System`.
- realtime `StoragePool` `UsagePercent` can be `$null`; use capacity history for capacity usage.
- Bond port examples require Bond ports to exist and should be treated as `NoData` when none exist.
- report-task names should be 31 characters or fewer.

## Tests Added or Updated

- Excel export default LUN performance limit is 25.
- Excel export user override changes the LUN limit.
- Excel export `-PerformanceLunLimit 0` allows unlimited LUN performance sampling.
- LUN performance is no longer skipped entirely above the old 500-object cap.
- Disk and Host capped safety behavior remains unchanged.
- `New-DMPerformanceReportTask` accepts 31-character names.
- `New-DMPerformanceReportTask` rejects 32-character names.

## Verification Results

- `git diff --check`: passed before focused testing.
- `Invoke-Pester Tests/Unit/Public/Export-functions.Tests.ps1 -Output Detailed`: 14 passed, 0 failed.
- `Invoke-Pester Tests/Unit/Public/New-DMPerformanceReportTask.Tests.ps1 -Output Detailed`: 14 passed, 0 failed.
- `Invoke-Pester Tests/Unit -Output Minimal`: 932 passed, 0 failed.

## Remaining Follow-Ups

- Consider optional metric applicability metadata in a future change.
- Consider a selected-object Excel export model if admins need more control than `-PerformanceLunLimit`.
- Re-run Bond port live validation on an array that actually has Bond ports.
