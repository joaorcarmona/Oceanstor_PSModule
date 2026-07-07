# Historical Performance and Capacity Guide

Navigation: [README](README.md) | [Block](BLOCK.md) | [NAS](NAS.md) | [Array](ARRAY.md) | [Troubleshooting](TROUBLESHOOTING.md) | [Implementation](IMPLEMENTATION.md)

Realtime performance shows the current sample. Historical performance and capacity use the OceanStor report-task workflow: create a report task, run/export it, poll for a log, download a ZIP, parse CSV rows, and clean up.

## Cmdlets

| Purpose | Cmdlet |
|---|---|
| High-level performance history | `Get-DMPerformanceHistory` |
| High-level capacity history | `Get-DMCapacityHistory` |
| Create raw report task | `New-DMPerformanceReportTask` |
| List report tasks | `Get-DMPerformanceReportTask` |
| Run/export report task | `Invoke-DMPerformanceReportTask` |
| Download export ZIP | `Save-DMPerformanceReportFile` |
| Remove report task | `Remove-DMPerformanceReportTask` |

## Why History Is Different

`Get-DMPerformance` uses `performance_data` and returns current JSON samples. `Get-DMPerformanceHistory` and `Get-DMCapacityHistory` use `pms/report_task` v2 APIs and CSV/ZIP output. They can be slower and require archived data on the array.

## Supported Object Types

Performance history supports:

- `LUN`
- `FileSystem`
- `Controller`
- `StoragePool`
- `Disk`
- `Host`
- `System`
- `FCPort`
- `EthernetPort`

Capacity history supports:

- `System`
- `StoragePool`

`BondPort` is supported for realtime performance but not currently validated for report-task history.

Report-task names must stay within the module validation limit of 31 characters. Prefer short debug names when using `New-DMPerformanceReportTask` directly.

## High-Level Flow

```text
Get-DMPerformanceHistory / Get-DMCapacityHistory
  -> New-DMPerformanceReportTask
  -> Invoke-DMPerformanceReportTask
  -> Save-DMPerformanceReportFile
  -> Import-DMPerformanceReportCsv
  -> New-DMPerformanceSample
  -> cleanup export log, report task, and local ZIP unless KeepReportTask
```

## Last Hour Controller Performance

```powershell
Get-DMPerformanceHistory -ObjectType Controller -ObjectId "0A" -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
```

Use this when a controller looked busy earlier and you need the trend after the incident.

## Last Hour LUN Performance

```powershell
$lun = Get-DMlun -Name "MyLun01"
Get-DMPerformanceHistory -ObjectType LUN -ObjectId $lun.Id -Metric TotalIOPS,ReadIOPS,WriteIOPS,AvgLatencyMs -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
```

Historical performance accepts object IDs, not LUN objects directly.

## NAS/FileSystem History

```powershell
$fs = Get-DMFileSystem | Select-Object -First 1
Get-DMPerformanceHistory -ObjectType FileSystem -ObjectId $fs.Id -Metric Ops,ReadOps,WriteOps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
```

Use NAS metrics for FileSystem history. Block latency names such as `AvgLatencyMs` are not the default NAS response-time model.

## Last Day Capacity History

Storage pool capacity:

```powershell
$pool = Get-DMstoragePool | Select-Object -First 1
Get-DMCapacityHistory -ObjectType StoragePool -ObjectId $pool.Id -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
```

System capacity:

```powershell
Get-DMCapacityHistory -ObjectType System -ObjectId 1 -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
```

Capacity CSV metric names are preserved from the array, for example `Total capacity(MB)`, `Used capacity(MB)`, and `Capacity usage(%)` when present.

Use capacity history, not realtime `Get-DMStoragePoolPerformance -Metric UsagePercent`, when you need pool capacity usage or usage trend data. Realtime `UsagePercent` can be `$null` for `StoragePool` objects.

## Debugging With KeepReportTask

Use `-KeepReportTask` only when you need to inspect raw report-task behavior:

```powershell
Get-DMPerformanceHistory -ObjectType Controller -ObjectId "0A" -Metric TotalIOPS,AvgLatencyMs -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date) -KeepReportTask
```

This leaves the temporary report task and export log on the array. Record the task ID and remove only the task you created.

Manual cleanup pattern:

```powershell
Get-DMPerformanceReportTask -Name "DMPerfHistory_*"
Remove-DMPerformanceReportTask -Id "<task-id>" -Confirm
```

Do not remove report tasks you did not create or confirm with the owner.

## Explicit Report Task Creation

Use this only when you need raw control over report-task lifecycle:

```powershell
$task = New-DMPerformanceReportTask -Name "pdoc_debug01" -ObjectType Controller -ObjectId "0A" -TimeSegment Customer -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date) -Metric TotalIOPS,AvgLatencyMs -Confirm
$log = Invoke-DMPerformanceReportTask -Id $task.Id -TimeoutSec 300 -Confirm
Save-DMPerformanceReportFile -LogId $log.LogId -TaskId $task.Id -Path "$env:TEMP\pdoc_debug01.zip" -Force
```

When done:

```powershell
Remove-DMPerformanceReportTask -Id $task.Id -Confirm
```

Use short task names and remove only the captured `$task.Id`. Live validation confirmed explicit create, invoke, download, and cleanup with a short task name.

## Zero Rows

Zero rows can mean:

- monitoring archive/history was disabled
- the selected time window has no archived data
- the selected object had no matching data
- the report-task API returned a firmware-specific CSV layout not covered by the parser
- the account lacks access to the report-task data

Check `Get-DMPerformanceMonitoring`, widen the time window, and try one known-active object.

## CSV/ZIP Parsing

`Save-DMPerformanceReportFile` downloads binary ZIP output through `Save-DMDeviceManagerFile`, which uses `Invoke-WebRequest -OutFile` to avoid JSON parsing corrupting the ZIP.

`Import-DMPerformanceReportCsv` extracts the ZIP, imports every `*.csv`, tags rows with `SourceFile`, and removes its temp extraction directory.

The live-confirmed CSV shape is long-format: one row per object/metric/timestamp, with metric names and indicator IDs in separate columns. A wide-format fallback exists for firmware with one metric per column.
