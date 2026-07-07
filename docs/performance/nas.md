# NAS/FileSystem Performance Guide

Navigation: [README](README.md) | [Array](array.md) | [History](history.md) | [Troubleshooting](troubleshooting.md) | [Implementation](implementation.md)

This guide covers `Get-DMFileSystemPerformance`, the `FileSystem` object type, and NAS-style metrics. NAS analysis is separated from block analysis because operation rate, response time, protocol behavior, and client mix often matter more than LUN-style IOPS alone.

## Supported Cmdlet

```powershell
Get-DMFileSystem | Get-DMFileSystemPerformance
```

`Get-DMFileSystemPerformance` accepts `OceanstorFileSystem` objects from the pipeline, batches IDs, and delegates to `Get-DMPerformance -ObjectType FileSystem`.

## NAS Metrics

| Metric | Unit | Meaning |
|---|---|---|
| `Ops` | `IO/s` | Total NAS operation rate. |
| `ReadOps` | `IO/s` | Read operation rate. |
| `WriteOps` | `IO/s` | Write operation rate. |
| `ReadBandwidthMBps` | `MB/s` | Read throughput. |
| `WriteBandwidthMBps` | `MB/s` | Write throughput. |
| `AvgReadOpsResponseTimeUs` | `us` | Average read operation response time. |
| `AvgWriteOpsResponseTimeUs` | `us` | Average write operation response time. |
| `NasServiceTimeUs` | `us` | NAS service-time indicator. |
| `AvgIOSizeKB` | `KB` | Average NAS I/O size. |
| `ReadBandwidthKBps`, `WriteBandwidthKBps` | `KB/s` | NAS bandwidth indicators in KB/s. |

NAS response-time metrics use `Us` names. The module does not convert them to milliseconds.

## Quick FileSystem Check

```powershell
Get-DMFileSystem |
    Select-Object -First 1 |
    Get-DMFileSystemPerformance -Metric Ops,ReadOps,WriteOps,ReadBandwidthMBps,WriteBandwidthMBps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs |
    Format-Table ObjectId,Timestamp,Ops,ReadOps,WriteOps,ReadBandwidthMBps,WriteBandwidthMBps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs
```

Use this to confirm the array is returning NAS counters for at least one file system.

## Identify Busy File Systems

```powershell
Get-DMFileSystem |
    Get-DMFileSystemPerformance -Metric Ops,ReadOps,WriteOps,ReadBandwidthMBps,WriteBandwidthMBps |
    Sort-Object Ops -Descending |
    Select-Object -First 10 ObjectType,ObjectId,Timestamp,Ops,ReadOps,WriteOps,ReadBandwidthMBps,WriteBandwidthMBps
```

This is the NAS equivalent of finding busy LUNs. Sort by `Ops` for operation pressure or by bandwidth for throughput-heavy workloads.

## Compare Read and Write Mix

```powershell
Get-DMFileSystem |
    Get-DMFileSystemPerformance -Metric Ops,ReadOps,WriteOps |
    Sort-Object Ops -Descending |
    Select-Object -First 10 ObjectId,Timestamp,Ops,ReadOps,WriteOps
```

Read-heavy and write-heavy NAS workloads often bottleneck differently. Use this view before comparing response-time metrics.

## Monitor NAS Response Time

```powershell
Get-DMFileSystem |
    Select-Object -First 10 |
    Get-DMFileSystemPerformance -Metric Ops,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs,NasServiceTimeUs |
    Sort-Object Ops -Descending |
    Format-Table ObjectId,Timestamp,Ops,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs,NasServiceTimeUs
```

If response time is high for only one file system, investigate its clients, shares, quotas, and backing pool. If many file systems are slow together, compare array, controller, pool, and port metrics.

## Monitor NAS Bandwidth

```powershell
Get-DMFileSystem |
    Get-DMFileSystemPerformance -Metric ReadBandwidthMBps,WriteBandwidthMBps,Ops,AvgIOSizeKB |
    Sort-Object ReadBandwidthMBps -Descending |
    Select-Object -First 10 ObjectId,Timestamp,ReadBandwidthMBps,WriteBandwidthMBps,Ops,AvgIOSizeKB
```

High `Ops` with low bandwidth can be a small-I/O workload. High bandwidth with moderate operations can be large-file throughput.

## Short Live Observation

```powershell
Get-DMFileSystem |
    Select-Object -First 5 |
    Get-DMFileSystemPerformance -Metric Ops,ReadOps,WriteOps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs -SampleCount 12 -IntervalSeconds 5 |
    Format-Table ObjectId,Timestamp,Ops,ReadOps,WriteOps,AvgReadOpsResponseTimeUs,AvgWriteOpsResponseTimeUs
```

Use `SampleCount` and `IntervalSeconds` for a short live watch. Keep the object set small.

## When Metrics Are Null

`$null` can mean:

- the array returned `-1`, which the module treats as not applicable
- the firmware does not expose the indicator for that object
- the file system exists but has no relevant activity in the sample window
- performance monitoring is disabled or stale

Check [array.md](array.md) for monitoring status and [troubleshooting.md](troubleshooting.md) for null-metric triage.
