# POSH-Oceanstor Performance Documentation

This folder documents the POSH-Oceanstor performance cmdlets from two angles:

- how storage administrators can use them during real SAN/NAS performance analysis
- how maintainers can understand and extend the implementation safely

The organization follows common enterprise storage practice: block workload analysis is separate from NAS workload analysis, array/controller health is separate from workload-level metrics, realtime monitoring is separate from historical trending, and implementation internals are separate from incident troubleshooting.

## Documentation Map

- [Block/SAN performance](BLOCK.md)
- [NAS/FileSystem performance](NAS.md)
- [Array and controller performance](ARRAY.md)
- [Historical performance and capacity](HISTORY.md)
- [Troubleshooting cookbook](TROUBLESHOOTING.md)
- [Implementation guide](IMPLEMENTATION.md)

## Quick Start

Check whether performance monitoring is enabled and whether realtime samples are available:

```powershell
Get-DMPerformanceMonitoring
Get-DMSystemPerformance
Get-DMController | Select-Object -First 1 | Get-DMControllerPerformance
```

Check one LUN:

```powershell
Get-DMlun -Name "MyLun01" |
    Get-DMLunPerformance -Metric TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,AvgLatencyMs
```

Check one file system:

```powershell
Get-DMFileSystem |
    Select-Object -First 1 |
    Get-DMFileSystemPerformance -Metric Ops,ReadOps,WriteOps,ReadBandwidthMBps,WriteBandwidthMBps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs
```

Get one hour of history for a controller:

```powershell
Get-DMPerformanceHistory -ObjectType Controller -ObjectId "0A" -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
```

## Cmdlet Families

| Family | Cmdlets | Use When |
|---|---|---|
| Generic realtime | `Get-DMPerformance` | You know the object type and object ID and want direct control. |
| Block wrappers | `Get-DMLunPerformance`, `Get-DMStoragePoolPerformance`, `Get-DMDiskPerformance`, `Get-DMHostPerformance`, `Get-DMPortPerformance` | You already have domain objects from getter cmdlets and want pipeline-friendly realtime samples. |
| NAS wrapper | `Get-DMFileSystemPerformance` | You need FileSystem/NAS operation, bandwidth, or response-time samples. |
| Array/controller | `Get-DMSystemPerformance`, `Get-DMControllerPerformance`, `Get-DMPerformanceMonitoring` | You need array-level smoke checks, controller balance, CPU, queue, or monitoring status. |
| Monitoring control | `Set-DMPerformanceMonitoring`, `Enable-DMPerformanceMonitoring`, `Disable-DMPerformanceMonitoring` | You intentionally need to change array monitoring settings. Use with care. |
| History/report tasks | `Get-DMPerformanceHistory`, `New-DMPerformanceReportTask`, `Get-DMPerformanceReportTask`, `Invoke-DMPerformanceReportTask`, `Save-DMPerformanceReportFile`, `Remove-DMPerformanceReportTask` | You need historical performance or raw report-task control. |
| Capacity history | `Get-DMCapacityHistory` | You need historical capacity for `System` or `StoragePool`. |
| Excel reporting | `Export-DMStorageToExcel` | You need a workbook with optional live performance worksheets. |

## Global Concepts

`Get-DMPerformance` is the generic realtime engine. Wrapper cmdlets collect object IDs from pipeline input and call the engine in batches. This is similar to the simple per-object UX admins expect from array SDKs, while keeping OceanStor raw indicator IDs behind friendly metric names.

Realtime data comes from `performance_data` JSON responses. Historical performance and capacity data come from report tasks and downloadable CSV/ZIP output. Historical calls are slower and can create temporary report-task metadata that the module removes by default.

Performance samples are dynamic `OceanStor.PerformanceSample` objects with:

- `ObjectType`
- `ObjectId`
- `Timestamp`
- one property per requested metric
- `RawIndicators` and `RawValues` when available
- `Session`

The Excel export path can add `ObjectName` to samples before writing worksheets, but realtime cmdlets generally return `ObjectId` rather than joined names.

## Metric Naming

Friendly metrics are defined in `POSH-Oceanstor/Private/DMPerformanceIndicatorMap.ps1`.

Common block metrics:

- `TotalIOPS`, `ReadIOPS`, `WriteIOPS`
- `BandwidthMBps`, `ReadBandwidthMBps`, `WriteBandwidthMBps`
- `AvgLatencyMs`, `ReadLatencyMs`, `WriteLatencyMs`
- `QueueLength`
- `CpuUsagePercent`
- `UsagePercent`

Common NAS metrics:

- `Ops`, `ReadOps`, `WriteOps`
- `ReadBandwidthMBps`, `WriteBandwidthMBps`
- `AvgReadOpsResponseTimeUs`, `AvgWriteOpsResponseTimeUs`
- `NasServiceTimeUs`
- `AvgIOSizeKB`

`Ms` latency metrics convert array microsecond values to milliseconds. NAS response-time metrics remain in microseconds because the implementation exposes them with `Us` names.

> Note: Metric applicability is not enforced by object type in code. If the array returns `-1`, the module surfaces that metric as `$null`.

## Realtime vs Historical Data

| Type | Data Source | Best For | Tradeoffs |
|---|---|---|---|
| Realtime | `performance_data` | Current checks, incident triage, short sample loops | Current sample only; depends on monitoring being enabled and current object support. |
| Historical performance | `pms/report_task` performance report | Last hour/day trends, post-incident checks | Slower, report-task based, needs archived history. |
| Capacity history | `pms/report_task` capacity report | Pool/system capacity trends | Only `System` and `StoragePool`; metric names come from CSV output. |
| Excel export | `Export-DMStorageToExcel -IncludeObject performance` | Lightweight workbook reporting | Live samples only; opt-in; object caps for large sections. |

## Safety Notes

- The examples in the operational guides use read-only performance checks unless explicitly labeled as report-task cleanup.
- `Get-DMPerformanceHistory` and `Get-DMCapacityHistory` create temporary report tasks and export logs, then clean them up unless `-KeepReportTask` is used.
- Do not use `-KeepReportTask` during routine checks unless you intend to inspect and manually clean up the task.
- `Set-DMPerformanceMonitoring`, `Enable-DMPerformanceMonitoring`, and `Disable-DMPerformanceMonitoring` can change live array behavior. Prefer `Get-DMPerformanceMonitoring` for normal troubleshooting.
- No examples use hostnames, credentials, or private lab addresses.

## Where To Go Next

Start with [Block/SAN performance](BLOCK.md) for LUN, pool, disk, host, and port analysis.

Use [NAS/FileSystem performance](NAS.md) for FileSystem OPS, bandwidth, and response time.

Use [Array and controller performance](ARRAY.md) for system workload, controller balance, CPU, queue, and monitoring status.

Use [Historical performance and capacity](HISTORY.md) when realtime samples are not enough.

Use [Troubleshooting cookbook](TROUBLESHOOTING.md) during incidents.

Use [Implementation guide](IMPLEMENTATION.md) when changing or extending the module.
