# Performance Implementation Guide

Navigation: [README](README.md) | [Block](block.md) | [NAS](nas.md) | [Array](array.md) | [History](history.md) | [Troubleshooting](troubleshooting.md)

This guide is for maintainers and contributors. It preserves the implementation detail that used to live in `README.ME` while the operational examples now live in focused guides.

## Architecture Overview

The performance implementation has these layers:

- generic realtime engine: `Get-DMPerformance`
- thin per-domain wrappers
- friendly metric names mapped to raw OceanStor indicator IDs
- dynamic sample factory: `New-DMPerformanceSample`
- monitoring status/control cmdlets
- report-task cmdlet family
- high-level performance and capacity history cmdlets
- Excel export integration
- unit and integration validation

This mirrors a common enterprise storage automation design: keep raw counter IDs out of the primary user workflow, offer simple per-entity cmdlets, and keep report/export mechanics behind higher-level history commands.

## Generic Realtime Engine

`Get-DMPerformance` wraps the `performance_data` endpoint.

Supported realtime object types:

| ObjectType | Numeric ID |
|---|---:|
| `Disk` | 10 |
| `LUN` | 11 |
| `FileSystem` | 40 |
| `EthernetPort` | 213 |
| `BondPort` | 235 |
| `FCPort` | 212 |
| `StoragePool` | 216 |
| `Controller` | 207 |
| `Host` | 21 |
| `System` | 201 |

Request body:

```powershell
@{
    object_type = <numeric object type ID>
    object_list = @(<object IDs>)
    indicators  = @(<indicator IDs>)
}
```

The cmdlet:

- resolves friendly metric names through `Get-DMPerformanceIndicatorMap`
- batches all pipeline `ObjectId` values into one request
- calls `Invoke-DeviceManager -Method POST -Resource performance_data`
- retries once for concurrency/in-progress style errors
- converts Unix seconds timestamps to UTC `datetime`
- converts selected latency metrics from microseconds to milliseconds
- converts raw `-1` values to `$null`
- preserves raw indicator IDs and values on the sample

## Wrapper Design

Wrappers validate domain objects and delegate to `Get-DMPerformance`.

| Wrapper | Input Type | ObjectType |
|---|---|---|
| `Get-DMLunPerformance` | `OceanstorLunv3`, `OceanstorLunv6` | `LUN` |
| `Get-DMControllerPerformance` | `OceanStorController` | `Controller` |
| `Get-DMStoragePoolPerformance` | `OceanStorStoragePool` | `StoragePool` |
| `Get-DMDiskPerformance` | `OceanStorDisks` | `Disk` |
| `Get-DMHostPerformance` | `OceanStorHost` | `Host` |
| `Get-DMPortPerformance` | port objects | `FCPort`, `EthernetPort`, `BondPort` |
| `Get-DMSystemPerformance` | none | `System`, object ID `0` |
| `Get-DMFileSystemPerformance` | `OceanstorFileSystem` | `FileSystem` |

Common wrapper parameters:

- `WebSession`
- `Metric`
- `SampleCount`
- `IntervalSeconds`

`Get-DMPortPerformance -PortType` supports only `FC`, `ETH`, and `Bond`.

Bond port support is implementation-backed, but live validation can only confirm it on arrays where `Get-DMPortBond` returns objects. Zero Bond ports should be reported as `NoData` in live checks.

## Indicator Map

`Get-DMPerformanceIndicatorMap` defines friendly metrics.

| Metric | ID | Unit | Notes |
|---|---:|---|---|
| `TotalIOPS` | 22 | `IO/s` | Block default. |
| `ReadIOPS` | 25 | `IO/s` | Block default. |
| `WriteIOPS` | 28 | `IO/s` | Block default. |
| `BandwidthMBps` | 21 | `MB/s` | Block default. |
| `ReadBandwidthMBps` | 23 | `MB/s` | Block and NAS default. |
| `WriteBandwidthMBps` | 26 | `MB/s` | Block and NAS default. |
| `AvgLatencyMs` | 370 | `ms` | Source unit `us`; converted. |
| `ReadLatencyMs` | 384 | `ms` | Source unit `us`; converted. |
| `WriteLatencyMs` | 385 | `ms` | Source unit `us`; converted. |
| `AvgLatencyUs` | 370 | `us` | Raw microseconds. |
| `ReadLatencyUs` | 384 | `us` | Raw microseconds. |
| `WriteLatencyUs` | 385 | `us` | Raw microseconds. |
| `ServiceTimeUs` | 369 | `us` | Raw microseconds. |
| `AvgReadIOSizeKB` | 24 | `KB` | Block I/O size. |
| `AvgWriteIOSizeKB` | 27 | `KB` | Block I/O size. |
| `QueueLength` | 19 | `count` | Block default. |
| `UsagePercent` | 18 | `%` | Object-dependent; realtime StoragePool samples may return `$null`. |
| `ReadCacheHitPercent` | 93 | `%` | Object-dependent. |
| `WriteCacheHitPercent` | 95 | `%` | Object-dependent. |
| `CpuUsagePercent` | 68 | `%` | Object-dependent. |
| `CacheUsagePercent` | 69 | `%` | Object-dependent. |
| `Ops` | 182 | `IO/s` | NAS default. |
| `ReadOps` | 232 | `IO/s` | NAS default. |
| `WriteOps` | 233 | `IO/s` | NAS default. |
| `AvgIOSizeKB` | 228 | `KB` | NAS. |
| `AvgReadOpsResponseTimeUs` | 524 | `us` | NAS default. |
| `AvgWriteOpsResponseTimeUs` | 525 | `us` | NAS default. |
| `NasServiceTimeUs` | 523 | `us` | NAS. |
| `ReadBandwidthKBps` | 123 | `KB/s` | NAS. |
| `WriteBandwidthKBps` | 124 | `KB/s` | NAS. |

## Default Metrics

Block/SAN default metrics:

```text
TotalIOPS
ReadIOPS
WriteIOPS
BandwidthMBps
ReadBandwidthMBps
WriteBandwidthMBps
AvgLatencyMs
ReadLatencyMs
WriteLatencyMs
QueueLength
```

NAS/FileSystem default metrics:

```text
Ops
ReadOps
WriteOps
ReadBandwidthMBps
WriteBandwidthMBps
AvgReadOpsResponseTimeUs
AvgWriteOpsResponseTimeUs
```

Defaults are chosen in `Get-DMPerformance` and `New-DMPerformanceReportTask`.

## Sample Object Shape

`New-DMPerformanceSample` returns a dynamic `[pscustomobject]` because the requested metric set changes per call.

Properties:

- `PSTypeName = OceanStor.PerformanceSample`
- `ObjectType`
- `ObjectId`
- `Timestamp`
- dynamic metric properties
- `RawIndicators`
- `RawValues`
- `Session`

The default display set includes `ObjectId`, `Timestamp`, and requested metrics.

## Monitoring Cmdlets

`Get-DMPerformanceMonitoring` reads:

- `performance_statistic_switch`
- `performance_statistic_strategy`

It returns `OceanStor.PerformanceMonitoringStatus` with:

- `Enabled`
- `BeginTime`
- `SamplingIntervalSeconds`
- `ArchiveEnabled`
- `ArchiveIntervalSeconds`
- `AutoStop`
- `MaxDays`

Mutating cmdlets:

- `Set-DMPerformanceMonitoring`
- `Enable-DMPerformanceMonitoring`
- `Disable-DMPerformanceMonitoring`

They use `SupportsShouldProcess`.

## Report-Task Cmdlets

`New-DMPerformanceReportTask` creates v2 `pms/report_task` tasks.

Supported report object types:

| ObjectType | `object_type` | `object_type_enum` |
|---|---|---:|
| `LUN` | `LUN` | 11 |
| `Controller` | `CONTROLLER` | 207 |
| `StoragePool` | `STORAGEPOOL` | 216 |
| `Disk` | `DISK` | 10 |
| `Host` | `HOST` | 21 |
| `System` | `SYSTEM` | 201 |
| `FCPort` | `FC_PORT` | 212 |
| `EthernetPort` | `ETH_PORT` | 213 |
| `FileSystem` | `FileSystem` | 40 |

Supported `ReportType` values are `Performance` and `Capacity`.

Supported `ComputeMode` values are `Avg` and `Max`.

Supported `TimeSegment` values are `OneHour`, `OneDay`, `OneWeek`, `OneMonth`, `OneYear`, and `Customer`.

`Customer` requires `StartTime` and `EndTime`. The implementation sends these as epoch milliseconds.

`Name` is validated to a maximum of 31 characters. Live validation confirmed the explicit report-task lifecycle with a short task name and rejected an overlong generated validation name before task creation. Unit tests pin both the 31-character accepted boundary and the 32-character rejected boundary.

## Report-Task Body

Top-level body includes:

- `name`
- `language`
- `retention_number`
- `format`
- `time_segment`
- `content`
- `frequency = day`
- `run_time = @{ hour = 0; min = 0 }`
- `begin_time` and `end_time` for `Customer`

Content includes:

- `report_type`
- `object_type`
- `object_type_enum`
- `sort_entities = customer`
- `indicators.basic`
- `indicators.advance`
- `entities`

Performance content also includes:

- `compute_mode`
- `sort_indicator`
- `sort_type = top`
- `limit`

Capacity content sends empty indicators and omits performance-only fields.

## History Internals

`Get-DMPerformanceHistory`:

1. Creates a temporary report task.
2. Invokes/export it.
3. Downloads the ZIP.
4. Imports CSV rows.
5. Pivots live-confirmed long-format CSV rows or uses a wide-format fallback.
6. Returns `OceanStor.PerformanceSample`.
7. Removes export log, report task, and local ZIP unless `-KeepReportTask` is set.

`Invoke-DMPerformanceReportTask` snapshots existing task-log IDs before export and treats the first new log entry as ready.

## Capacity History Internals

`Get-DMCapacityHistory` uses `New-DMPerformanceReportTask -ReportType Capacity`. It supports only `System` and `StoragePool`.

Capacity metrics are not mapped through `Get-DMPerformanceIndicatorMap`; the cmdlet preserves CSV metric display names from the array.

## CSV / ZIP Download

`Save-DMPerformanceReportFile` uses `Save-DMDeviceManagerFile`, which builds the API URI and uses `Invoke-WebRequest -OutFile` so binary ZIP output is not parsed as JSON.

The live file endpoint requires both `log_id` and `task_id`.

`Import-DMPerformanceReportCsv` extracts the ZIP, imports all CSV files, tags rows with `SourceFile`, and removes its temp extraction directory.

## Excel Export Integration

`Export-DMStorageToExcel` supports `performance` in `-IncludeObject`.

Behavior:

- `performance` is opt-in only
- `full` does not imply `performance`
- samples System, Controllers, StoragePools, Disks, Hosts, and LUNs
- skips Disk/Host performance sections above 500 objects
- limits LUN performance to the first 25 inventory LUNs by default via `-PerformanceLunLimit`
- supports `-PerformanceLunLimit 0` when the caller explicitly wants no LUN limit
- joins `ObjectName` from source object IDs before writing worksheets
- depends on `Export-Excel`

The LUN limit is first-N from the already collected inventory, not true top-N by IOPS. True top-N would require sampling every LUN first, which is not a safe default for Excel export on large arrays.

## Tests

Unit tests cover:

- indicator and object-type maps
- request body construction
- default metrics
- conversion and null projection
- sample object shape
- wrapper delegation and batching
- monitoring GET/PUT behavior
- report-task body construction
- history/capacity cleanup
- CSV import
- Excel export opt-in/cap/`PerformanceLunLimit` behavior

Integration tests are opt-in and staged:

- realtime checks are read-only
- Excel checks write local files only
- history/capacity checks create report tasks only
- test-created report tasks are tracked and cleaned up by ID
- baseline protection avoids deleting pre-existing report tasks
- monitoring mutation is separately gated

## Cleanup and Safety Model

High-level history cmdlets clean up:

- export logs
- temporary report tasks
- local ZIP files

`-KeepReportTask` intentionally disables report-task cleanup for debugging.

## Add a New Performance Object Type

1. Confirm the realtime object type ID.
2. Add it to `$script:DMPerformanceObjectTypeMap`.
3. Add it to `Get-DMPerformance` `ValidateSet`.
4. If history is supported, add it to `Get-DMPerformanceReportObjectTypeMap` and report-task/history `ValidateSet` values.
5. Add or verify metrics in `Get-DMPerformanceIndicatorMap`.
6. Decide whether defaults should be block, NAS, or a new set.
7. Add a wrapper cmdlet if useful.
8. Export the function in the module manifest.
9. Add unit tests.
10. Add safe integration coverage if possible.
11. Update these docs.

## Add a New Metric

1. Confirm indicator ID and unit from REST reference or live validation.
2. Add a friendly name to `Get-DMPerformanceIndicatorMap`.
3. Decide whether conversion is needed.
4. Add to defaults only if broadly useful.
5. Add tests for validation, ID resolution, conversion, and `$null` behavior.
6. Update docs.

## Implementation Debugging

Useful checks:

```powershell
Get-DMPerformanceMonitoring
Get-DMPerformance -ObjectType System -ObjectId 0 -Metric TotalIOPS,AvgLatencyMs
Get-DMPerformanceHistory -ObjectType Controller -ObjectId "0A" -Metric TotalIOPS -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date) -KeepReportTask
```

For report-task issues, inspect:

- created task body
- task ID returned or found by name
- task log query
- file download URL requiring both `log_id` and `task_id`
- CSV layout

Do not change implementation behavior while updating docs.
