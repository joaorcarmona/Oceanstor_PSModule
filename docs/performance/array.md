# Array and Controller Performance Guide

Navigation: [README](README.md) | [Block](block.md) | [NAS](nas.md) | [History](history.md) | [Troubleshooting](troubleshooting.md) | [Implementation](implementation.md)

Array and controller checks answer a different question than LUN or FileSystem checks: is the problem local to one workload, or is the array/controller layer under pressure?

## Supported Cmdlets

| Area | Cmdlet |
|---|---|
| Monitoring status | `Get-DMPerformanceMonitoring` |
| System realtime | `Get-DMSystemPerformance` |
| Controller realtime | `Get-DMControllerPerformance` |
| Monitoring changes | `Set-DMPerformanceMonitoring`, `Enable-DMPerformanceMonitoring`, `Disable-DMPerformanceMonitoring` |

Routine troubleshooting should start read-only. Changing monitoring policy can affect live collection and retention.

## Quick Array Smoke Check

```powershell
Get-DMPerformanceMonitoring
Get-DMSystemPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent
```

Look for:

- `Enabled` in monitoring status
- current `Timestamp`
- `$null` metrics
- high `AvgLatencyMs`
- high `QueueLength` where applicable
- high `CpuUsagePercent` where applicable

## Monitoring Status

`Get-DMPerformanceMonitoring` combines `performance_statistic_switch` and `performance_statistic_strategy`.

Important output fields:

| Property | Meaning |
|---|---|
| `Enabled` | Whether realtime collection is enabled. |
| `SamplingIntervalSeconds` | Realtime sampling interval. |
| `ArchiveEnabled` | Whether archive/history collection is enabled. |
| `ArchiveIntervalSeconds` | Historical archive interval. |
| `AutoStop` | Whether statistics collection stops automatically. |
| `MaxDays` | Retention limit. |

Do not change monitoring settings during an incident unless you understand the array policy impact. The mutating cmdlets support `-WhatIf` and `-Confirm`, but this guide keeps examples read-only.

## System IOPS, Bandwidth, Latency, Queue, and CPU

```powershell
Get-DMSystemPerformance -Metric TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,ReadBandwidthMBps,WriteBandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent |
    Format-Table ObjectId,Timestamp,TotalIOPS,ReadIOPS,WriteIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent
```

`QueueLength` is the closest implemented friendly metric to an array/object queue signal. There is no separate friendly metric named `ArrayQueue`.

`CpuUsagePercent` is implemented as a friendly metric, but applicability is array/object dependent. If the array does not return it for `System`, the sample may show `$null`.

Live validation against one OceanStor array confirmed `CpuUsagePercent` on `System`, while `QueueLength` returned `$null` for the system object. Treat queue metrics as object/firmware dependent.

## Controller Performance and Imbalance

```powershell
Get-DMController |
    Get-DMControllerPerformance -Metric TotalIOPS,BandwidthMBps,CpuUsagePercent,AvgLatencyMs,QueueLength |
    Sort-Object ObjectId |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,CpuUsagePercent,AvgLatencyMs,QueueLength
```

Compare controllers for:

- one controller carrying much more IOPS or bandwidth
- one controller with higher CPU
- one controller with higher latency or queue

An imbalance can point to host pathing, ownership/preference behavior, workload placement, or front-end port distribution. Confirm with [block.md](block.md) port and host checks.

## Local vs Global Problem

Use array and controller metrics to decide where to drill next:

| Observation | Next Check |
|---|---|
| One LUN slow, system/controller normal | Check host paths, front-end ports, and that LUN's pool. |
| Many LUNs slow, controller CPU/latency high | Check controller balance, port pressure, and global workload. |
| FileSystems slow, system bandwidth/CPU high | Check NAS operation mix and backend pool. |
| Realtime samples stale or empty | Check `Get-DMPerformanceMonitoring`. |
| History unavailable | Check `ArchiveEnabled` and [history.md](history.md). |

## Short Array Observation

```powershell
Get-DMSystemPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent -SampleCount 12 -IntervalSeconds 5 |
    Format-Table ObjectId,Timestamp,TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent
```

This gives a one-minute live view without creating report tasks.
