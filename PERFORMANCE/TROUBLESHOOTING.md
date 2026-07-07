# Performance Troubleshooting Cookbook

Navigation: [README](README.md) | [Block](BLOCK.md) | [NAS](NAS.md) | [Array](ARRAY.md) | [History](HISTORY.md) | [Implementation](IMPLEMENTATION.md)

This cookbook is written for operational triage. The examples are read-only unless a report-task cleanup command is explicitly shown.

## 1. High LUN Latency

Symptoms:

- application reports storage latency
- host latency is elevated
- one LUN or a small LUN set is suspected

Commands:

```powershell
Get-DMlun -Name "MyLun01" |
    Get-DMLunPerformance -Metric TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,AvgLatencyMs,ReadLatencyMs,WriteLatencyMs,QueueLength

Get-DMstoragePool |
    Get-DMStoragePoolPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength

Get-DMController |
    Get-DMControllerPerformance -Metric CpuUsagePercent,TotalIOPS,BandwidthMBps,AvgLatencyMs

Get-DMPortFc |
    Get-DMPortPerformance -PortType FC -Metric TotalIOPS,BandwidthMBps
```

Interpretation:

- LUN high, pool normal: look at host paths, front-end ports, or the specific object.
- LUN high, pool high: backend pool pressure is more likely.
- Controller CPU high or one controller much busier: check balance.
- Ports uneven or saturated: investigate fabric/path distribution.

## 2. High Array Workload

Symptoms:

- multiple applications are slow
- global IOPS or bandwidth is high
- many LUNs or FileSystems show pressure

Commands:

```powershell
Get-DMSystemPerformance -Metric TotalIOPS,BandwidthMBps,CpuUsagePercent,AvgLatencyMs,QueueLength

Get-DMController |
    Get-DMControllerPerformance -Metric TotalIOPS,BandwidthMBps,CpuUsagePercent,AvgLatencyMs

Get-DMlun |
    Select-Object -First 100 |
    Get-DMLunPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object TotalIOPS -Descending |
    Select-Object -First 10 ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```

Next safe checks:

- compare busiest LUNs with affected applications
- check NAS busy file systems if file workloads are present
- use `Get-DMPerformanceHistory` if the spike already passed

## 3. Unbalanced Controllers

Symptoms:

- one controller reports higher CPU, bandwidth, or latency
- host paths appear uneven
- one controller handles most workload

Commands:

```powershell
Get-DMController |
    Get-DMControllerPerformance -Metric TotalIOPS,BandwidthMBps,CpuUsagePercent,AvgLatencyMs,QueueLength |
    Sort-Object ObjectId |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,CpuUsagePercent,AvgLatencyMs,QueueLength
```

Compare controller values side by side. If one controller is consistently hotter, check host pathing, preferred paths, port utilization, and workload placement.

## 4. Suspected Front-End Port Saturation

Symptoms:

- host latency rises while backend pool looks normal
- traffic appears concentrated on a subset of ports
- FC or Ethernet interfaces are suspected

Commands:

```powershell
Get-DMPortFc |
    Get-DMPortPerformance -PortType FC -Metric TotalIOPS,BandwidthMBps |
    Sort-Object BandwidthMBps -Descending

Get-DMPortETH |
    Get-DMPortPerformance -PortType ETH -Metric TotalIOPS,BandwidthMBps |
    Sort-Object BandwidthMBps -Descending

Get-DMPortBond |
    Get-DMPortPerformance -PortType Bond -Metric TotalIOPS,BandwidthMBps |
    Sort-Object BandwidthMBps -Descending
```

Supported port types are `FC`, `ETH`, and `Bond`. No `FCoE` or `IB` `-PortType` is implemented.

If `Get-DMPortBond` returns no objects, treat the Bond check as `NoData`; the Bond performance wrapper is still valid when Bond ports exist.

## 5. Busy Storage Pool

Symptoms:

- several LUNs in the same pool are slow
- backend latency appears shared
- capacity usage may be relevant

Commands:

```powershell
Get-DMstoragePool |
    Get-DMStoragePoolPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,UsagePercent |
    Sort-Object TotalIOPS -Descending |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,UsagePercent
```

If one pool is hotter than others, identify its busiest LUNs and check disk samples.

If capacity usage is part of the question, prefer capacity history because realtime `StoragePool` `UsagePercent` can be `$null`:

```powershell
Get-DMCapacityHistory -ObjectType StoragePool -ObjectId "<pool-id>" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
```

## 6. Disk Hotspot

Symptoms:

- pool latency is high
- backend disk imbalance is suspected
- a subset of media may be busy

Commands:

```powershell
Get-DMdisk |
    Select-Object -First 100 |
    Get-DMDiskPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object TotalIOPS -Descending |
    Select-Object -First 20 ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```

Use disk results as a directional clue. Some disk metrics can be `$null` depending on disk/media type and firmware support.

## 7. NAS/FileSystem Workload Spike

Symptoms:

- NAS users report slow shares
- file operations are high
- one file system may be noisy

Commands:

```powershell
Get-DMFileSystem |
    Get-DMFileSystemPerformance -Metric Ops,ReadOps,WriteOps,ReadBandwidthMBps,WriteBandwidthMBps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs |
    Sort-Object Ops -Descending |
    Select-Object -First 10 ObjectId,Timestamp,Ops,ReadOps,WriteOps,ReadBandwidthMBps,WriteBandwidthMBps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs
```

Interpretation:

- high `Ops` with low bandwidth: many small operations
- high bandwidth with moderate operations: throughput workload
- high response time on many file systems: check array/controller/pool pressure
- high response time on one file system: investigate that file system and its clients

## 8. Historical Trend Investigation

Symptoms:

- issue is intermittent
- realtime looks normal now
- you need a last-hour or last-day trend

Commands:

```powershell
Get-DMSystemPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs

Get-DMPerformanceHistory -ObjectType System -ObjectId 0 -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
```

For a specific LUN:

```powershell
$lun = Get-DMlun -Name "MyLun01"
Get-DMPerformanceHistory -ObjectType LUN -ObjectId $lun.Id -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
```

Historical data requires archived data and report-task support.

## 9. Metrics Are Null

Symptoms:

- selected properties are `$null`
- only some metrics populate
- a metric works on one object type but not another

Checks:

```powershell
Get-DMPerformanceMonitoring
Get-DMSystemPerformance
Get-DMPerformance -ObjectType LUN -ObjectId 1 -Metric TotalIOPS,AvgLatencyMs,QueueLength
```

Interpretation:

- the array may have returned `-1`, which the module converts to `$null`
- the metric may not apply to that object type
- firmware may not expose the indicator
- the object may not have current activity

Do not assume `$null` is zero.

Live validation examples: `QueueLength` returned `$null` on the system object, and realtime `StoragePool` `UsagePercent` returned `$null` for the tested pool. Other metrics from the same samples returned numeric values, so the right interpretation was "not applicable or not returned for this object", not "no workload".

## 10. Performance Monitoring Disabled

Symptoms:

- no realtime samples
- stale timestamps
- history is empty

Command:

```powershell
Get-DMPerformanceMonitoring
```

If `Enabled` or `ArchiveEnabled` is false, decide with the storage owner before changing settings. The module has `Set-DMPerformanceMonitoring`, `Enable-DMPerformanceMonitoring`, and `Disable-DMPerformanceMonitoring`, but changing monitoring policy is not a routine read-only troubleshooting step.

## 11. Historical Report Returns No Rows

Symptoms:

- `Get-DMPerformanceHistory` returns no samples
- `Get-DMCapacityHistory` returns no samples

Checks:

```powershell
Get-DMPerformanceMonitoring
Get-DMPerformanceHistory -ObjectType System -ObjectId 0 -Metric TotalIOPS -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
```

Try:

- widen the time range
- test a known-active object
- confirm archive is enabled
- confirm the account can use report-task APIs
- check whether `-KeepReportTask` helps inspect raw output

## 12. Report Task Fails or Times Out

Symptoms:

- `Get-DMPerformanceHistory` times out
- `Invoke-DMPerformanceReportTask` times out
- no new export log appears

Checks:

```powershell
Get-DMPerformanceReportTask
Get-DMPerformanceHistory -ObjectType Controller -ObjectId "0A" -Metric TotalIOPS -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date) -TimeoutSec 300
```

If debugging raw behavior:

```powershell
Get-DMPerformanceHistory -ObjectType Controller -ObjectId "0A" -Metric TotalIOPS -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date) -TimeoutSec 300 -KeepReportTask
```

Remember to remove only the kept task you created.

## 13. Excel Export Performance Section Missing

Symptoms:

- workbook has inventory but no performance sheets
- performance sections are missing for LUNs/disks/hosts

Checks:

```powershell
Export-DMStorageToExcel -OceanStor $storage -ReportFile ".\storage-performance.xlsx" -IncludeObject performance
Export-DMStorageToExcel -OceanStor $storage -ReportFile ".\storage-performance.xlsx" -IncludeObject performance -PerformanceLunLimit 100
Export-DMStorageToExcel -OceanStor $storage -ReportFile ".\storage-full-with-performance.xlsx" -IncludeObject full,performance
```

Interpretation:

- `performance` is opt-in; `full` alone does not include it
- Disk and Host performance sections are skipped above the 500-object cap
- LUN performance defaults to the first 25 LUNs from the collected inventory; use `-PerformanceLunLimit` to increase it, or `-PerformanceLunLimit 0` for no LUN limit
- `Export-Excel` must be available
- the export uses live realtime samples, not history

The Excel LUN limit is first-N from inventory, not true top-N by IOPS. For true top-busy LUN analysis, use:

```powershell
Get-DMlun |
    Select-Object -First 100 |
    Get-DMLunPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object TotalIOPS -Descending |
    Select-Object -First 25 ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```
