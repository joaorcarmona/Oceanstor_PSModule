# Block/SAN Performance Guide

Navigation: [README](README.md) | [Array](array.md) | [History](history.md) | [Troubleshooting](troubleshooting.md) | [Implementation](implementation.md)

This guide covers LUN, storage pool, disk, host, and front-end port performance. It is written for the workflow most SAN administrators use during triage: start with the affected workload, compare backend pool/disk behavior, then check controller and port pressure.

## Supported Cmdlets

| Area | Cmdlet |
|---|---|
| Generic realtime engine | `Get-DMPerformance` |
| LUNs | `Get-DMLunPerformance` |
| Storage pools | `Get-DMStoragePoolPerformance` |
| Disks | `Get-DMDiskPerformance` |
| Hosts | `Get-DMHostPerformance` |
| Ports | `Get-DMPortPerformance -PortType FC`, `ETH`, or `Bond` |

## Block Metrics

| Metric | Meaning |
|---|---|
| `TotalIOPS`, `ReadIOPS`, `WriteIOPS` | Workload rate and read/write mix. |
| `BandwidthMBps`, `ReadBandwidthMBps`, `WriteBandwidthMBps` | Throughput in MB/s. |
| `AvgLatencyMs`, `ReadLatencyMs`, `WriteLatencyMs` | Latency in milliseconds. The module converts these from array microseconds. |
| `QueueLength` | Queue/backlog signal where the array exposes the indicator for that object. |
| `AvgReadIOSizeKB`, `AvgWriteIOSizeKB` | Average I/O size. Useful when IOPS is high but bandwidth is lower than expected. |
| `UsagePercent` | Object-type dependent usage indicator. |

Metric applicability is array/object dependent. A returned raw value of `-1` is shown as `$null`.

## Quick LUN Check

```powershell
Get-DMlun -Name "MyLun01" |
    Get-DMLunPerformance -Metric TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,ReadBandwidthMBps,WriteBandwidthMBps,AvgLatencyMs,ReadLatencyMs,WriteLatencyMs |
    Format-Table ObjectId,Timestamp,TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,AvgLatencyMs,ReadLatencyMs,WriteLatencyMs
```

Use this when an application team names a specific volume. Read/write split and latency together usually matter more than a single IOPS number.

## Monitor One LUN Over Time

```powershell
Get-DMlun -Name "MyLun01" |
    Get-DMLunPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength -SampleCount 12 -IntervalSeconds 5 |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength
```

This collects 12 live samples, five seconds apart. It is useful for short incident windows without creating report tasks.

## Monitor Multiple LUNs

Select by name pattern:

```powershell
Get-DMlun -Name "SQL*" |
    Select-Object -First 20 |
    Get-DMLunPerformance -Metric TotalIOPS,ReadIOPS,WriteIOPS,AvgLatencyMs |
    Format-Table ObjectId,Timestamp,TotalIOPS,ReadIOPS,WriteIOPS,AvgLatencyMs
```

Summarize total IOPS for a selected set:

```powershell
Get-DMlun -Name "SQL*" |
    Select-Object -First 20 |
    Get-DMLunPerformance -Metric TotalIOPS |
    Measure-Object -Property TotalIOPS -Sum
```

## LUN Group-Style Workflows

There is no `Get-DMLunGroupPerformance` wrapper. The supported workflow is to resolve member LUNs first, then pipe them to `Get-DMLunPerformance`.

```powershell
Get-DMlun -LunGroupName "ProductionLuns" |
    Get-DMLunPerformance -Metric TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,AvgLatencyMs |
    Format-Table ObjectId,Timestamp,TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,AvgLatencyMs
```

`Get-DMlun` also supports `-LunGroup`, `-LunGroupId`, and `-LunGroupName`. The older `Get-DMlunbyLunGroup` exists for compatibility, but the current pattern is `Get-DMlun -LunGroup...`.

## Identify Top Busy LUNs

```powershell
Get-DMlun |
    Select-Object -First 100 |
    Get-DMLunPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object TotalIOPS -Descending |
    Select-Object -First 10 ObjectType,ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```

On large arrays, cap the candidate set or filter by name/pool/application first. The wrapper batches IDs, but asking every LUN for performance can still be noisy.

To include names, join them from the source LUN objects:

```powershell
$luns = Get-DMlun -Name "SQL*" | Select-Object -First 100
$namesById = @{}
$luns | ForEach-Object { $namesById[$_.Id] = $_.Name }

$luns |
    Get-DMLunPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object TotalIOPS -Descending |
    Select-Object -First 10 @{Name='ObjectName';Expression={$namesById[$_.ObjectId]}},ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```

## Storage Pool Performance

```powershell
Get-DMstoragePool |
    Get-DMStoragePoolPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,UsagePercent |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,UsagePercent
```

Pool metrics help distinguish workload-local issues from backend pressure. If one LUN is slow and the pool is also slow, investigate pool, disk, and controller pressure. If the pool is healthy, check host paths and front-end ports.

Live validation confirmed realtime pool IOPS, bandwidth, latency, and queue values. `UsagePercent` existed as a friendly metric but returned `$null` for the tested pool; use [history.md](history.md) capacity history for confirmed capacity fields:

```powershell
Get-DMCapacityHistory -ObjectType StoragePool -ObjectId "<pool-id>" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
```

## Disk Performance

```powershell
Get-DMdisk |
    Select-Object -First 20 |
    Get-DMDiskPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object TotalIOPS -Descending |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```

Disk samples are useful for spotting hotspots or imbalance. Not every disk/media type exposes every block metric.

## Host Performance

`Get-DMHostPerformance` is implemented and batches `OceanStorHost` objects.

```powershell
Get-DMhost |
    Select-Object -First 20 |
    Get-DMHostPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object TotalIOPS -Descending |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```

Use this to compare host-side workload distribution when a subset of hosts reports latency or path pressure.

## Front-End Port Performance

Supported `-PortType` values are `FC`, `ETH`, and `Bond`.

FC:

```powershell
Get-DMPortFc |
    Get-DMPortPerformance -PortType FC -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs |
    Sort-Object BandwidthMBps -Descending |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs
```

Ethernet:

```powershell
Get-DMPortETH |
    Get-DMPortPerformance -PortType ETH -Metric TotalIOPS,BandwidthMBps |
    Sort-Object BandwidthMBps -Descending |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps
```

Bond:

```powershell
Get-DMPortBond |
    Get-DMPortPerformance -PortType Bond -Metric TotalIOPS,BandwidthMBps |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps
```

FCoE and InfiniBand are not exposed as `Get-DMPortPerformance -PortType` values in the current implementation.

Live validation confirmed FC and Ethernet port examples. `Bond` is supported by the cmdlet syntax, but the validation array had no Bond ports, so Bond examples are syntax-accurate but environment-dependent. Treat zero Bond ports as `NoData`, not as a module failure.

## Common SAN Flow

1. Check the affected LUN: IOPS, bandwidth, latency, queue.
2. Compare sibling LUNs or the LUN group selection.
3. Check the storage pool for shared backend pressure.
4. Check disk hotspots.
5. Check controller balance and CPU in [array.md](array.md).
6. Check front-end port bandwidth and imbalance.
7. Use [history.md](history.md) if the issue is intermittent or already passed.
