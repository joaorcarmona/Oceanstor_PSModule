# Performance Documentation Live Validation Gap Analysis

Navigation: [README](README.md) | [Block](BLOCK.md) | [NAS](NAS.md) | [Array](ARRAY.md) | [History](HISTORY.md) | [Troubleshooting](TROUBLESHOOTING.md) | [Implementation](IMPLEMENTATION.md)

## Validation Date

2026-07-07

## Storage Target

10.10.10.24

## Summary

Live validation connected to the OceanStor array, exercised representative read-only realtime examples, tested report-task history and capacity flows, and created a local Excel workbook. No LUNs, hosts, mappings, file systems, storage pools, controllers, disks, or ports were created or modified.

Most documentation examples were confirmed. The main gaps were object-dependent `$null` metrics, Bond port examples depending on Bond ports existing, a large-array LUN performance export cap, and the need to keep manual report-task names within the 31-character validation limit.

## Files Validated

- `PERFORMANCE/README.md`
- `PERFORMANCE/BLOCK.md`
- `PERFORMANCE/NAS.md`
- `PERFORMANCE/ARRAY.md`
- `PERFORMANCE/HISTORY.md`
- `PERFORMANCE/TROUBLESHOOTING.md`
- `PERFORMANCE/IMPLEMENTATION.md`
- `PERFORMANCE/README.ME`

## Commands Tested

Representative examples were validated from these command families:

- `Get-DMPerformanceMonitoring`
- `Get-DMSystemPerformance`
- `Get-DMController | Get-DMControllerPerformance`
- `Get-DMlun | Get-DMLunPerformance`
- `Get-DMlun -LunGroupName ... | Get-DMLunPerformance`
- `Get-DMstoragePool | Get-DMStoragePoolPerformance`
- `Get-DMdisk | Get-DMDiskPerformance`
- `Get-DMhost | Get-DMHostPerformance`
- `Get-DMPortFc | Get-DMPortPerformance -PortType FC`
- `Get-DMPortETH | Get-DMPortPerformance -PortType ETH`
- `Get-DMFileSystem | Get-DMFileSystemPerformance`
- `Get-DMPerformanceHistory`
- `Get-DMCapacityHistory`
- `New-DMPerformanceReportTask`, `Invoke-DMPerformanceReportTask`, `Save-DMPerformanceReportFile`, `Remove-DMPerformanceReportTask`
- `Export-DMStorageToExcel -IncludeObject performance`

## Confirmed Examples

| Area | Result |
|---|---|
| Monitoring status | `Get-DMPerformanceMonitoring` returned one status object. |
| System realtime | System IOPS, bandwidth, latency, and CPU examples returned samples. |
| Controller realtime | Controller performance and imbalance examples returned two controller samples. |
| LUN realtime | Single-LUN, sample-loop, multi-LUN, top-LUN, and LUN group-style workflows returned samples. |
| Storage pool realtime | Pool IOPS, bandwidth, latency, and queue examples returned a sample. |
| Disk realtime | Disk examples returned samples. |
| Host realtime | Host examples returned samples. |
| Port realtime | FC and Ethernet examples returned samples. |
| NAS/FileSystem realtime | FileSystem OPS, bandwidth, response-time, sort, and sample-loop examples returned samples. |
| Performance history | Controller, LUN, and FileSystem history examples returned historical rows. |
| Capacity history | StoragePool and System capacity history examples returned rows. |
| Explicit report task | Short-name create, invoke, ZIP download, and cleanup were confirmed. |
| Excel export | Performance workbook creation was confirmed. |

## Corrected Examples

| Documentation file | Section | Expected | Actual | Action taken |
|---|---|---|---|---|
| `HISTORY.md` | Explicit Report Task Creation | Manual task name can be any reasonable debug name. | Generated validation name longer than 31 characters was rejected by module validation. A short name succeeded. | Added a 31-character name caveat and changed the example to a shorter name. |
| `README.md`, `ARRAY.md`, `TROUBLESHOOTING.md` | System queue examples | `QueueLength` may be populated for system checks. | `QueueLength` returned `$null` on the tested system sample while other metrics populated. | Added object/firmware caveat. |
| `BLOCK.md`, `TROUBLESHOOTING.md` | Storage pool usage | `UsagePercent` may be populated in realtime pool samples. | `UsagePercent` returned `$null` for the tested pool while performance metrics populated. | Added caveat and pointed capacity checks to capacity history. |
| `BLOCK.md` | Bond port examples | Bond port command is supported. | No Bond ports existed on the test array. | Marked Bond example as syntax-supported but environment-dependent. |
| `TROUBLESHOOTING.md`, `IMPLEMENTATION.md` | Excel performance export | Performance workbook includes available performance sections. | Workbook was created; LUN performance was skipped because 1220 LUNs exceeded the 500-object cap. | Added live validation note for cap behavior. |

## Unsupported or Removed Examples

No documented cmdlet example was removed as unsupported. No `Get-DMLunGroupPerformance`, unsupported CPU metric, unsupported queue metric, unsupported NAS metric, unsupported port type, or destructive workflow was added.

`Bond` port performance remains documented because the implementation supports `-PortType Bond`; it is clearly caveated because no Bond ports were available on the validation array.

## Skipped Examples

| Area | Reason |
|---|---|
| Bond port live sample | No Bond ports were returned by the array. |
| Creating temporary LUNs, hosts, mappings, or file systems | Existing read-only objects were sufficient for validation. |

## Expected vs Actual Findings

| Documentation file | Section | Expected | Actual | Action taken |
|---|---|---|---|---|
| `README.md` | Quick Start | Realtime system/controller checks run read-only. | Confirmed. System `QueueLength` was `$null`. | Added metric applicability note. |
| `BLOCK.md` | LUN workflows | LUN samples can be gathered directly, over time, by selection, and by LUN group member resolution. | Confirmed. | No command correction needed. |
| `BLOCK.md` | Storage Pool Performance | Pool performance and usage can be requested. | Performance values returned; `UsagePercent` was `$null`. | Added capacity-history guidance. |
| `BLOCK.md` | Front-End Port Performance | FC, ETH, and Bond commands are documented. | FC and ETH confirmed. Bond skipped because no Bond ports existed. | Added caveat. |
| `NAS.md` | NAS/FileSystem examples | OPS, bandwidth, response-time, sort, and sample-loop examples run. | Confirmed. | No command correction needed. |
| `ARRAY.md` | Queue and CPU | CPU and queue are friendly metrics, but object applicability can vary. | CPU populated on System; System queue was `$null`. | Added live validation note. |
| `HISTORY.md` | History examples | History creates report tasks, downloads/parses data, and cleans up. | Confirmed for Controller, LUN, FileSystem, StoragePool capacity, and System capacity. | No command correction needed. |
| `HISTORY.md` | Explicit report task | Manual lifecycle can be performed safely with captured IDs. | Confirmed with a short task name. | Added name-length caveat. |
| `TROUBLESHOOTING.md` | Excel export missing section | Large collections can be skipped by cap. | Confirmed with 1220 LUNs. | Added live validation note. |

## Metrics Confirmed

The following friendly metrics returned non-null values in at least one live sample:

- `TotalIOPS`
- `ReadIOPS`
- `WriteIOPS`
- `BandwidthMBps`
- `ReadBandwidthMBps`
- `WriteBandwidthMBps`
- `AvgLatencyMs`
- `ReadLatencyMs`
- `WriteLatencyMs`
- `QueueLength`
- `CpuUsagePercent`
- `Ops`
- `ReadOps`
- `WriteOps`
- `AvgReadOpsResponseTimeUs`
- `AvgWriteOpsResponseTimeUs`
- `NasServiceTimeUs`
- capacity CSV fields including `Total capacity(MB)`, `Used capacity(MB)`, `Capacity usage(%)`, and `Mapped LUN capacity(MB)`

## Metrics Not Supported or Not Returned

| Metric | Finding |
|---|---|
| `QueueLength` on `System` | Returned `$null` on the tested system object. |
| `UsagePercent` on realtime `StoragePool` | Returned `$null` on the tested pool. Capacity history returned capacity fields separately. |
| Bond port metrics | Not live-confirmed because no Bond ports were available. |

No unsupported friendly metric names were added to the examples.

## Object Types Available on Test Array

| Object type | Count |
|---|---:|
| Monitoring status rows | 1 |
| Controllers | 2 |
| Storage pools | 1 |
| LUNs | 1220 |
| LUN groups | 8 |
| Disks | 12 |
| Hosts | 215 |
| FC ports | 8 |
| Ethernet ports | 24 |
| Bond ports | 0 |
| FileSystems | 221 |
| Pre-existing report tasks | 0 |

## Objects Created for Validation

| Object kind | Object ID or path | Name | Purpose |
|---|---|---|---|
| Report task | `88010feb-3be0-4520-83a2-01e70891447a` | `DMPerfHistory_63e889a121be401bb` | `Get-DMPerformanceHistory -KeepReportTask` validation. |
| Report task | `958fce41-06e7-4c7d-b598-4bed97ba5da2` | `pdoc_aa5b9196` | Explicit report-task lifecycle validation. |
| Local file | temporary validation path | `perf_doc_test_20260707022224_2490ee2f_storage-performance.xlsx` | Excel export validation. |
| Local file | temporary validation path | `pdoc_aa5b9196.zip` | Explicit report-task download validation. |

No LUNs, LUN groups, hosts, host groups, mappings, file systems, storage pools, controllers, disks, or ports were created.

## Cleanup Results

All validation-created report tasks and local validation files were removed by captured ID/path during validation cleanup.

Remaining created objects reported by the validation cleanup registry: none.

## Remaining Risks

- Results are from one live array and one firmware/API behavior set.
- A metric that returned `$null` on this array may populate on another model, firmware level, or object type.
- Bond port examples are implementation-supported but were not live-confirmed because the validation array had no Bond ports.
- Historical data depends on archive collection and the selected time window.
- Excel export behavior depends on the local `Export-Excel` command being available.

## Follow-Up Recommendations

- Re-run validation on an array with Bond ports if Bond examples are operationally important.
- Add automated documentation smoke tests for command syntax where possible.
- Consider adding an example-safe validation harness to the integration test suite so future documentation changes can be checked without modifying storage objects.
