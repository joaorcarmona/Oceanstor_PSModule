# Performance API and Command Validation Failures

## Scope

This report analyzes only the failed, skipped, corrected, not-confirmed, or caveated behavior from the live performance documentation validation recorded in [VALIDATION-GAP-ANALYSIS.md](VALIDATION-GAP-ANALYSIS.md). It does not treat confirmed examples as failures, and it does not propose code or documentation edits as implemented work.

The live validation target was `10.10.10.24` on 2026-07-07. No credentials are included here.

## Sources Reviewed

- `PERFORMANCE/VALIDATION-GAP-ANALYSIS.md`
- `PERFORMANCE/README.md`
- `PERFORMANCE/BLOCK.md`
- `PERFORMANCE/NAS.md`
- `PERFORMANCE/ARRAY.md`
- `PERFORMANCE/HISTORY.md`
- `PERFORMANCE/TROUBLESHOOTING.md`
- `PERFORMANCE/IMPLEMENTATION.md`
- `PERFORMANCE/README.ME`
- `POSH-Oceanstor/Public/Get-DMPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMSystemPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMStoragePoolPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMPortPerformance.ps1`
- `POSH-Oceanstor/Public/Get-DMPerformanceHistory.ps1`
- `POSH-Oceanstor/Public/Get-DMCapacityHistory.ps1`
- `POSH-Oceanstor/Public/New-DMPerformanceReportTask.ps1`
- `POSH-Oceanstor/Public/Invoke-DMPerformanceReportTask.ps1`
- `POSH-Oceanstor/Public/Save-DMPerformanceReportFile.ps1`
- `POSH-Oceanstor/Public/Remove-DMPerformanceReportTask.ps1`
- `POSH-Oceanstor/Public/Export-DMStorageToExcel.ps1`
- `POSH-Oceanstor/Private/DMPerformanceIndicatorMap.ps1`
- `Tests/Unit/Public/*Performance*.Tests.ps1`
- `Tests/Unit/Private/*Performance*.Tests.ps1`
- `Tests/Integration/Private/Workflows/Performance*.ps1`
- `OceanStor Dorado 6.1.6 REST Interface Reference.md`

## Executive Summary

No clear OceanStor REST API defect was identified from the available validation data. The module used the expected `performance_data` and `pms/report_task` resources, the key object type IDs matched the REST reference, and the confirmed examples demonstrated that the core realtime, history, capacity, and Excel paths work.

The main findings are narrower:

- `QueueLength` on `System` returned `$null`; this is best classified as metric applicability/documentation caveat because the module does not enforce per-object metric applicability and the visible REST reference table does not clearly list System for that indicator.
- `UsagePercent` on realtime `StoragePool` returned `$null`; this is best classified as documentation caveat plus possible metric-applicability enhancement because the REST reference table shows indicator `18` for Ethernet, Bond, and FC ports, not StoragePool.
- Bond port performance was skipped only because the validation array had no Bond ports; this is an environment/object-availability issue, not a module or firmware failure.
- Excel performance export skipped LUN performance because 1220 LUNs exceeded the module's intentional 500-object cap; this is an intentional safeguard with possible usability improvements.
- An overlong generated report-task name was rejected by module validation; the REST reference says length 32, but module comments and live validation indicate practical 31-character behavior. This is correct conservative module validation with a documentation caveat.

## Classification Summary

| Classification | Count | Findings |
|---|---:|---|
| Documentation-only issue | 2 | System queue caveat, realtime StoragePool usage caveat |
| Module implementation issue | 0 | No confirmed implementation bug from this data |
| Module implementation improvement | 3 | Optional metric applicability metadata, configurable Excel cap, clearer selected-object export guidance |
| Firmware/API behavior issue | 0 | No clear defect identified |
| Environment/object-availability issue | 1 | Bond ports unavailable on validation array |
| Intentional safeguard | 2 | Excel 500-object cap, report-task 31-character validation |

## Command / API Failure Matrix

| Area | Command / Example | API Resource | Metric / Field | Expected | Actual | Classification | Action |
|---|---|---|---|---|---|---|---|
| System realtime | `Get-DMSystemPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent` | `POST performance_data` | `QueueLength` / indicator `19`, object type `201` | Queue might populate as a system-level queue signal. | Sample returned; `QueueLength` was `$null`; other metrics populated. | Documentation caveat; possible metric applicability enhancement | Keep example with caveat; do not treat `$null` as zero. |
| Storage pool realtime | `Get-DMstoragePool | Get-DMStoragePoolPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,UsagePercent` | `POST performance_data` | `UsagePercent` / indicator `18`, object type `216` | Pool usage might populate in realtime sample. | Sample returned; performance metrics populated; `UsagePercent` was `$null`. | Documentation caveat; possible metric applicability enhancement | Prefer `Get-DMCapacityHistory` for pool capacity usage. |
| Bond port realtime | `Get-DMPortBond | Get-DMPortPerformance -PortType Bond -Metric TotalIOPS,BandwidthMBps` | `POST performance_data` after port inventory query | object type `235` | Bond port samples can be tested when Bond ports exist. | Skipped because validation array returned zero Bond ports. | Environment/object-availability issue | Keep syntax example with environment caveat; validate on array with Bond ports. |
| Excel export | `Export-DMStorageToExcel -OceanStor $storage -ReportFile ... -IncludeObject performance` | `POST performance_data` through wrapper cmdlets | LUN performance worksheet | Workbook includes available performance sections. | Workbook created; LUN performance skipped because 1220 LUNs exceeded 500-object cap. | Intentional safeguard; documentation/usability issue | Keep cap documented; consider configurable cap or selected-object export guidance. |
| Report task creation | `New-DMPerformanceReportTask -Name <long-name> ...` | `POST api/v2/pms/report_task` | `name` | Documentation validation expected a generated debug name to be accepted. | Name longer than 31 characters rejected by module validation before API call. | Correct module validation; documentation caveat | Keep examples short; note REST reference says 32 but live behavior supports 31. |

## Detailed Findings

### Finding 1 - `QueueLength` on `System` Returned `$null`

Command-level behavior:

- Command: `Get-DMSystemPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent`
- Documentation sections: `README.md` Quick Start and Metric Naming, `ARRAY.md` System IOPS/Bandwidth/Latency/Queue/CPU, `TROUBLESHOOTING.md` High Array Workload and Metrics Are Null.
- Expected: A system performance sample with numeric values where supported.
- Actual: The command succeeded and returned a system sample. `QueueLength` returned `$null`; other metrics populated.
- Status: Succeeded with caveat.
- Safety: Read-only.
- Should remain documented: Yes, with explicit object/firmware applicability caveat.

Module implementation path:

- Public wrapper: `Get-DMSystemPerformance`
- Generic engine: `Get-DMPerformance`
- Metric map: `QueueLength = @{ Id = 19; Unit = 'count' }`
- Object type map: `System = 201`
- REST call: `Invoke-DeviceManager -Method POST -Resource performance_data`
- Null handling: `Get-DMPerformance` converts raw `-1` values to `$null` and also leaves a metric `$null` if the response omits that indicator.

REST API path:

- `POST /deviceManager/rest/{deviceId}/performance_data`
- Body shape: `object_type = 201`, `object_list = @('0')`, `indicators` includes `19`.

Huawei REST reference comparison:

- The `performance_data` POST interface is documented in section `4.14.1.1.2`.
- The visible object type list in that endpoint documents common block object types such as Disk `10`, Controller `207`, LUN `11`, Ethernet port `213`, Bond port `235`, FC port `212`, and StoragePool `216`.
- The block indicator table in appendix `5.4.1` lists `Queue Length` / indicator `19` for LUN, Controller, StoragePool, EthernetPort, LIF, BondPort, Host, Disk domain, I/O class, and FCPort.
- The visible table does not clearly list System `201` for indicator `19`, although report-task schema examples do document `SYSTEM (201)` for reports and live validation confirmed some system performance metrics.

Classification:

- Primary: Documentation caveat.
- Secondary: Potential module enhancement for metric applicability metadata.
- Not a confirmed firmware/API defect because the reference excerpt does not clearly guarantee `QueueLength` for System.
- Not a confirmed module bug because the module intentionally allows any friendly metric name and surfaces unsupported/not-applicable values as `$null`.

Recommendation:

- Keep `QueueLength` examples only with wording such as "where applicable."
- Consider adding optional metric applicability metadata to `DMPerformanceIndicatorMap.ps1`, but do not fail existing requests by default; existing behavior is useful for firmware variance.

### Finding 2 - `UsagePercent` on Realtime `StoragePool` Returned `$null`

Command-level behavior:

- Command: `Get-DMstoragePool | Get-DMStoragePoolPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,UsagePercent`
- Documentation sections: `BLOCK.md` Storage Pool Performance, `TROUBLESHOOTING.md` Busy Storage Pool, `README.md` Metric Naming.
- Expected: Pool performance sample, possibly including usage.
- Actual: Pool performance sample returned. IOPS, bandwidth, latency, and queue values populated; `UsagePercent` returned `$null`.
- Status: Succeeded with caveat.
- Safety: Read-only.
- Should remain documented: The command can remain, but capacity usage should be framed as object-dependent. Capacity trend examples should use `Get-DMCapacityHistory`.

Module implementation path:

- Public wrapper: `Get-DMStoragePoolPerformance`
- Generic engine: `Get-DMPerformance`
- Metric map: `UsagePercent = @{ Id = 18; Unit = '%' }`
- Object type map: `StoragePool = 216`
- REST call: `POST performance_data`
- Capacity alternative: `Get-DMCapacityHistory -ObjectType StoragePool`, which creates a `pms/report_task` capacity report with empty performance indicators.

REST API path:

- Realtime: `POST /deviceManager/rest/{deviceId}/performance_data`
- Historical/capacity alternative: `POST /api/v2/pms/report_task`, `GET pms/report_task/export`, `GET pms/report_task/task_log`, `GET pms/report_task/file`.

Huawei REST reference comparison:

- Appendix `5.4.1` shows indicator `18` as `Usage (%)`.
- In the visible block table, `Usage (%)` is marked for Ethernet port, Bond port, and FC port columns, not StoragePool `216`.
- StoragePool `216` is listed as a valid `performance_data` object type.
- Capacity report-task output live-confirmed fields such as `Total capacity(MB)`, `Used capacity(MB)`, and `Capacity usage(%)`.

Classification:

- Primary: Documentation caveat.
- Secondary: Potential module metric-applicability improvement.
- Not a confirmed firmware/API defect because the REST reference does not clearly show realtime `UsagePercent` as supported for StoragePool.
- Not a confirmed module bug because the module's global metric map does not currently encode applicability.

Recommendation:

- Do not present realtime `UsagePercent` as a reliable StoragePool metric.
- Prefer `Get-DMCapacityHistory -ObjectType StoragePool` for pool usage trend examples.
- Consider adding metadata that says indicator `18` applies to EthernetPort, BondPort, FCPort, Disk, SAS Port, and other reference-listed objects, but not StoragePool unless later live validation proves otherwise.

### Finding 3 - Bond Port Performance Was Not Live-Confirmed

Command-level behavior:

- Command: `Get-DMPortBond | Get-DMPortPerformance -PortType Bond -Metric TotalIOPS,BandwidthMBps`
- Documentation sections: `BLOCK.md` Front-End Port Performance, `TROUBLESHOOTING.md` Suspected Front-End Port Saturation, `IMPLEMENTATION.md` object type map.
- Expected: If Bond ports exist, pipe Bond port objects to `Get-DMPortPerformance`.
- Actual: Skipped because the validation array returned zero Bond ports.
- Status: Skipped/not confirmed.
- Safety: Read-only.
- Should remain documented: Yes, with caveat that it requires Bond ports.

Module implementation path:

- Public wrapper: `Get-DMPortPerformance`
- Getter dependency: `Get-DMPortBond`
- Generic engine: `Get-DMPerformance`
- Object type map: `BondPort = 235`
- PortType switch: `Bond` maps to `BondPort`.

REST API path:

- Inventory: Bond port query APIs such as `/bond_port` or equivalent module getter resource.
- Realtime: `POST performance_data` with object type `235`.

Huawei REST reference comparison:

- The `performance_data` POST endpoint lists `235: bond port`.
- Appendix `5.4.1` includes the Bond port column and lists several block indicators including `Usage (%)` and `Queue Length` as applicable.
- The REST reference also documents Bond port management and query interfaces.

Classification:

- Environment/object-availability issue.
- Not a module bug.
- Not a firmware/API defect.

Recommendation:

- Keep the example.
- Add or retain wording that live confirmation requires an array with Bond ports.
- Add a future live integrity test gate that records `NoData` when no Bond ports exist rather than failing.

### Finding 4 - Excel Export Skipped LUN Performance Above 500 Objects

Command-level behavior:

- Command: `Export-DMStorageToExcel -OceanStor $storage -ReportFile ".\storage-performance.xlsx" -IncludeObject performance`
- Documentation sections: `README.md` Realtime vs Historical Data, `TROUBLESHOOTING.md` Excel Export Performance Section Missing, `IMPLEMENTATION.md` Excel Export Integration.
- Expected: Workbook is created with available performance worksheets.
- Actual: Workbook was created. LUN performance was skipped because 1220 LUN objects exceeded the 500-object cap.
- Status: Succeeded with caveat.
- Safety: Read-only against the array; writes local workbook only.
- Should remain documented: Yes.

Module implementation path:

- Public cmdlet: `Export-DMStorageToExcel`
- Cap variable: `$script:DMPerformanceExcelObjectCap = 500`
- Performance sections sampled: System, Controllers, StoragePools, Disks, Hosts, LUNs.
- Cap applies to Disk, Host, and LUN sections.
- Warning: "Skipping <section> performance: <count> objects exceeds the 500-object cap. Use <wrapper> directly with a smaller selection if needed."

REST API path:

- Uses wrapper cmdlets such as `Get-DMLunPerformance`, which call `POST performance_data`.
- No separate Excel REST API.

Huawei REST reference comparison:

- The `performance_data` endpoint states that it cannot be invoked concurrently.
- The REST reference does not define this 500-object cap; it is a module safeguard.

Classification:

- Intentional safeguard.
- Documentation gap already corrected in docs.
- Possible implementation improvement if admins need configurable exports.

Recommendation:

- Keep the cap.
- Consider adding `-PerformanceObjectCap` or an explicit selected-object export model if operational demand justifies it.
- Keep docs explaining that large sections can be skipped and that wrapper cmdlets should be used for smaller selected sets.

### Finding 5 - Report-Task Name Longer Than 31 Characters Was Rejected

Command-level behavior:

- Command pattern: `New-DMPerformanceReportTask -Name <generated-long-name> -ObjectType Controller -ObjectId "0A" -TimeSegment Customer ...`
- Documentation sections: `HISTORY.md` Explicit Report Task Creation, `IMPLEMENTATION.md` Report-Task Cmdlets.
- Expected: The generated validation name would be accepted.
- Actual: Module validation rejected names longer than 31 characters. A targeted rerun using a short name succeeded through create, invoke, ZIP download, and cleanup.
- Status: Initial validation harness issue; explicit short-name workflow confirmed.
- Safety: Creates and deletes a report task. Safe only when task ID is captured and cleanup is by ID.
- Should remain documented: Yes, with short-name examples.

Module implementation path:

- Public cmdlet: `New-DMPerformanceReportTask`
- Parameter validation: `[ValidateLength(1, 31)]` and `[ValidatePattern('^[A-Za-z0-9_.-]+$')]`
- API resource: `POST pms/report_task` with `-ApiV2`
- Comments state the REST document says 32 characters, but live Dorado behavior created no task for a 32-character name, so module rejects longer than 31.

REST API path:

- `POST /api/v2/pms/report_task`
- Related flow: `GET pms/report_task`, `GET pms/report_task/export`, `GET pms/report_task/task_log`, `GET pms/report_task/file`, `DELETE pms/report_task/{id}`.

Huawei REST reference comparison:

- The REST reference create-report-task section says `name` length is `32`.
- Module comments and live validation indicate practical 31-character behavior.
- This is not enough to claim a current firmware bug from this run alone because the failed command did not call the API; it was rejected by module validation.

Classification:

- Correct conservative module validation.
- Documentation caveat.
- Possible Huawei clarification request, not a defect report.

Recommendation:

- Keep examples under 31 characters.
- Add a unit test for `[ValidateLength(1,31)]` if one does not already exist.
- If a future support case is opened, reproduce with raw API outside module validation using a 32-character name and collect the response and subsequent task query.

## Huawei REST Reference Comparison

| Topic | Reference Evidence | Code Behavior | Live Result | Assessment |
|---|---|---|---|---|
| `performance_data` endpoint | POST `/deviceManager/rest/{deviceId}/performance_data` documented for realtime batches. | `Get-DMPerformance` uses `POST performance_data`. | Confirmed across many object types. | Correct. |
| Object type `StoragePool` | Endpoint lists StoragePool `216`. | Module maps `StoragePool = 216`. | Pool performance sample returned. | Correct. |
| Object type `BondPort` | Endpoint lists Bond port `235`; Bond port APIs exist. | Module maps `BondPort = 235` and supports `-PortType Bond`. | Not tested because no Bond ports existed. | Implementation matches reference; environment gap. |
| `QueueLength` indicator | Appendix `5.4.1` lists indicator `19` for several block object columns. Visible table does not clearly include System `201`. | Module maps `QueueLength = 19` globally. | `$null` for System; non-null elsewhere. | Applicability caveat, not proven defect. |
| `UsagePercent` indicator | Appendix `5.4.1` lists indicator `18`; visible block table marks it for Ethernet, Bond, and FC ports, not StoragePool. | Module maps `UsagePercent = 18` globally. | `$null` for StoragePool realtime. | Applicability caveat, not proven defect. |
| Report-task name | Reference says report task `name` length `32`. | Module validates maximum `31` based on prior live behavior noted in comments. | Long validation name rejected by module; short name confirmed. | Conservative validation; possible reference/live behavior discrepancy to clarify. |
| Report-task schema | Reference documents `report_type`, `object_type`, `object_type_enum`, indicators, entities, schedule fields. | `New-DMPerformanceReportTask` sends these fields. | Explicit report-task flow confirmed. | Correct. |

## Metric Analysis

| Friendly Metric | Indicator ID | Object Type Requested | REST Reference Applicability | Live Result | Classification | Recommendation |
|---|---:|---|---|---|---|---|
| `QueueLength` | 19 | `System` / `201` | `Queue Length` is documented for several block object types; visible table does not clearly list System `201`. | `$null` on System; other System metrics populated. | Documentation caveat | Keep request allowed; document as object-dependent. |
| `UsagePercent` | 18 | `StoragePool` / `216` | Visible `5.4.1` table marks Usage for Ethernet, Bond, and FC ports, not StoragePool. | `$null` on tested pool; capacity history returned capacity fields. | Documentation caveat | Use capacity history for StoragePool capacity usage. |
| `TotalIOPS` | 22 | Multiple | Block metric documented and live-confirmed. | Non-null in at least one sample. | Confirmed | No action. |
| `BandwidthMBps` | 21 | Multiple | Block metric documented and live-confirmed. | Non-null in at least one sample. | Confirmed | No action. |
| `CpuUsagePercent` | 68 | `System`, `Controller` | Metric exists in module map; applicability object-dependent. | Non-null on System during validation. | Confirmed with caveat | Keep caveat wording. |
| Bond port metrics | 21, 22, 18, 19, others | `BondPort` / `235` | BondPort is listed in object type and indicator tables. | Not run; no Bond ports existed. | Environment/object availability | Validate on Bond-equipped array. |

## API Analysis

| API Resource | Used By | Reference Status | Live Status | Issue | Recommendation |
|---|---|---|---|---|---|
| `performance_data` | `Get-DMPerformance` and all realtime wrappers | Documented as realtime/batch endpoint; cannot be invoked concurrently. | Confirmed for System, Controller, LUN, LUN group-style member selection, StoragePool, Disk, Host, FC, ETH, FileSystem. | Object-dependent null metrics. | Keep global engine; add applicability docs/tests. |
| `performance_statistic_switch` | `Get-DMPerformanceMonitoring` | Documented monitoring control/status area. | Confirmed. | None. | No action. |
| `performance_statistic_strategy` | `Get-DMPerformanceMonitoring` and mutating monitoring cmdlets | Documented monitoring strategy area. | Confirmed read-only. | None. | No action. |
| `pms/report_task` | `New-DMPerformanceReportTask`, history/capacity cmdlets | Documented v2 report-task create/query/delete resource. | Confirmed with short names. | Name length reference/live mismatch is possible but not proven in this run. | Keep 31-char validation; optional Huawei clarification. |
| `pms/report_task/export` | `Invoke-DMPerformanceReportTask` | Documented report export trigger. | Confirmed. | None. | No action. |
| `pms/report_task/task_log` | `Invoke-DMPerformanceReportTask`, cleanup | Documented/used to find export log. | Confirmed. | None from this validation. | No action. |
| `pms/report_task/file` | `Save-DMPerformanceReportFile` | Documented/used for binary ZIP download. | Confirmed. | Requires both `log_id` and `task_id` per module comments/live behavior. | Keep documented. |
| Bond port query resource | `Get-DMPortBond` | Bond port query APIs documented. | Returned zero objects on validation array. | No object available. | Validate elsewhere if needed. |

## Firmware / API Issues to Report to Huawei

No clear firmware/API defect was identified from the available validation data.

The only possible Huawei clarification item is the report-task name length discrepancy: the REST reference says `name` length `32`, while module comments record live behavior where a 32-character name was acknowledged but not created, so the module validates a maximum of `31`. The validation in this task did not submit a 32-character raw API request because module validation correctly blocked overlong names before the API call.

## Firmware / API Issue Report Draft

### Environment

- Product: OceanStor Dorado
- REST reference used: OceanStor Dorado 6.1.6 REST Interface Reference
- Storage target: 10.10.10.24
- Date observed: 2026-07-07

### Issue Summary

No clear firmware/API defect was proven by this validation. A documentation/API clarification may be useful for `pms/report_task.name` length. The REST reference states length `32`, while prior module comments and validation behavior use a practical limit of `31`.

### REST API Endpoint

`POST /api/v2/pms/report_task`

### Request Context

Report-task creation for performance history using `report_type = performance`, `object_type = CONTROLLER`, `object_type_enum = 207`, `time_segment = customer`, and a manually provided task name.

### Expected Behavior Based on Documentation

The reference states that the report task `name` field has length `32`.

### Actual Behavior Observed

In this validation, overlong names were rejected by module validation before reaching the API. The module carries an implementation note from earlier live validation that 32-character names were acknowledged by the array but no task was created, so the module currently uses a 31-character limit.

### Business Impact

Low. Users can use names of 31 characters or fewer. The main risk is confusing documentation or automation that assumes a 32-character task name is valid.

### Reproduction Steps

1. Use a non-production validation array.
2. Submit a raw `POST /api/v2/pms/report_task` request with a 32-character `name`.
3. Confirm whether the API response reports success.
4. Query `GET /api/v2/pms/report_task` and verify whether a task with that exact name exists.
5. Repeat with a 31-character name as control.

### Evidence Collected

- Module validation uses `[ValidateLength(1,31)]`.
- A short task name was live-confirmed through create, invoke, download, and cleanup.
- The REST reference says `name` length `32`.

### Questions for Huawei

- Is `pms/report_task.name` intended to allow 32 characters or only 31?
- If 32 is documented, should a 32-character name create a task reliably?
- Are there model, firmware, language, or character-set conditions that change the practical limit?

## Module Implementation Issues

No confirmed module implementation bug was identified.

Potential implementation improvements:

- Add optional metric applicability metadata to `DMPerformanceIndicatorMap.ps1`.
- Add a warning mode for metrics known not to apply to requested object types.
- Add a configurable Excel performance object cap if large-array reporting needs it.
- Add a direct selected-object Excel performance export path only if it fits the module's export design.

## Module Correction Plan

### Correction 1 - Add Metric Applicability Metadata

Severity: Medium

Affected files:

- `POSH-Oceanstor/Private/DMPerformanceIndicatorMap.ps1`
- `POSH-Oceanstor/Public/Get-DMPerformance.ps1`
- `Tests/Unit/Private/DMPerformanceIndicatorMap.Tests.ps1`
- `Tests/Unit/Public/Get-DMPerformance.Tests.ps1`

Reason:

The current metric map validates names globally but does not encode which object types the REST reference lists for each indicator. This makes documentation and user expectations broader than the API guarantees.

Proposed change:

Add optional `AppliesTo` metadata to indicator entries. Keep existing behavior by default, but optionally warn when a user requests a metric that is known not to apply to the requested object type.

Tests to add/update:

- Map contains expected `AppliesTo` metadata for `QueueLength` and `UsagePercent`.
- `Get-DMPerformance` still allows firmware-dependent requests.
- Optional warning behavior, if implemented, is tested without breaking current callers.

Risk:

Medium. Strict enforcement could break users who rely on firmware-specific indicators. Prefer warning or documentation first.

Recommended implementation model:

Metric applicability/map corrections: Fable or Opus, High for first correction.

### Correction 2 - Make Excel Performance Cap Configurable

Severity: Low

Affected files:

- `POSH-Oceanstor/Public/Export-DMStorageToExcel.ps1`
- Excel export unit/integration tests
- Performance documentation

Reason:

The 500-object cap is a useful safeguard but cannot be tuned by advanced users.

Proposed change:

Add an optional `-PerformanceObjectCap` parameter with default `500`, or document a separate selected-object workflow instead of changing the cmdlet.

Tests to add/update:

- Default cap still skips Disk/Host/LUN sections above 500.
- Custom cap changes skip behavior.
- Warning includes object count and cap.

Risk:

Low to medium. Larger caps can increase array/API load and workbook size.

Recommended implementation model:

Documentation-only corrections: Sonnet, Medium. Endpoint/body/schema corrections are not involved.

### Correction 3 - Add Report-Task Name Length Test

Severity: Low

Affected files:

- `Tests/Unit/Public/New-DMPerformanceReportTask.Tests.ps1`

Reason:

The 31-character validation is intentional and should be pinned by a unit test.

Proposed change:

Add tests that 31-character names bind and 32-character names fail at parameter validation.

Tests to add/update:

- `New-DMPerformanceReportTask` accepts a 31-character name.
- `New-DMPerformanceReportTask` rejects a 32-character name.

Risk:

Low.

Recommended implementation model:

Unit tests: Sonnet, Medium.

## Documentation-Only Issues

| File | Section | Current Problem | Recommended Text/Change |
|---|---|---|---|
| `README.md` | Metric Naming | Global metric list can imply universal applicability. | Keep explicit note that metric applicability is object/firmware dependent and `$null` is not zero. |
| `ARRAY.md` | System IOPS, Bandwidth, Latency, Queue, and CPU | System queue may be interpreted as guaranteed. | Say `QueueLength` is a closest available friendly metric and may be `$null` on System. |
| `BLOCK.md` | Storage Pool Performance | `UsagePercent` on realtime pool can look guaranteed. | Prefer capacity history for capacity usage; realtime `UsagePercent` is object-dependent. |
| `BLOCK.md` | Front-End Port Performance | Bond example may look live-confirmed everywhere. | Keep caveat that Bond ports must exist. |
| `TROUBLESHOOTING.md` | Excel Export Performance Section Missing | Large-array cap needs operational explanation. | Keep note that Disk/Host/LUN performance sections are skipped above cap. |
| `HISTORY.md` | Explicit Report Task Creation | Manual task names may be too long. | Use names of 31 characters or fewer. |

## Environment/Object-Availability Issues

| Issue | Environment Finding | Impact | Recommendation |
|---|---|---|---|
| Bond port validation | Test array returned zero Bond ports. | Bond port command could not be live-confirmed. | Re-run on an array with Bond ports if Bond port docs must be marked live-confirmed. |
| Large LUN inventory | Test array returned 1220 LUNs. | Excel LUN performance skipped by cap. | Use wrapper cmdlets for selected LUNs or consider configurable cap. |

## Recommended Correction Plan

1. Keep current documentation caveats for System `QueueLength`, StoragePool realtime `UsagePercent`, Bond ports, Excel caps, and report-task name length.
2. Add unit tests for report-task name length.
3. Decide whether metric applicability metadata should be warning-only or documentation-only.
4. If adding metric applicability metadata, start with `QueueLength` and `UsagePercent`, because those were live-caveated.
5. Add a live integrity test branch for Bond ports that reports `NoData` when no Bond ports exist.
6. Consider making the Excel cap configurable only if admins regularly need full large-array performance exports.
7. If Huawei clarification is needed, reproduce the 32-character report-task name behavior with a raw API request, not through the module.

## Suggested Unit Tests

- `Get-DMPerformance` preserves `$null` when a requested indicator is omitted by the array response.
- `Get-DMPerformance` converts raw `-1` to `$null` for unsupported/not-applicable values.
- `DMPerformanceIndicatorMap` documents indicator `18` and `19` applicability if metadata is added.
- `New-DMPerformanceReportTask` accepts 31-character names and rejects 32-character names.
- `Export-DMStorageToExcel` warns and skips capped LUN sections above 500 objects.
- `Export-DMStorageToExcel` does not include performance when only `full` is requested.

## Suggested Live Integrity Tests

- System realtime performance: assert sample shape and record whether `QueueLength` is null, without failing on null.
- StoragePool realtime performance: assert sample shape and record whether `UsagePercent` is null, without failing on null.
- Bond port realtime performance: if Bond ports exist, run `Get-DMPortPerformance -PortType Bond`; otherwise report `NoData`.
- Excel performance export: validate workbook creation and record skipped sections/cap warnings.
- Report-task name boundary: only if safe and explicitly gated, submit 31-character and 32-character names through raw or module paths and clean up by captured ID.

## Open Questions

- Is `System` object type `201` officially supported by `performance_data` for all mapped block metrics, or only for a subset?
- Should the module expose metric applicability warnings, or is documentation enough given firmware variance?
- Should `UsagePercent` remain in block examples outside port/disk contexts?
- Should `Export-DMStorageToExcel` support selected-object performance exports, or should users keep using wrappers directly?
- Does Huawei officially support 32-character `pms/report_task.name` values on the validated firmware?

## Appendix A - Commands Reviewed

- `Get-DMSystemPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,CpuUsagePercent`
- `Get-DMstoragePool | Get-DMStoragePoolPerformance -Metric TotalIOPS,BandwidthMBps,AvgLatencyMs,QueueLength,UsagePercent`
- `Get-DMPortBond | Get-DMPortPerformance -PortType Bond -Metric TotalIOPS,BandwidthMBps`
- `Export-DMStorageToExcel -OceanStor $storage -ReportFile ".\storage-performance.xlsx" -IncludeObject performance`
- `New-DMPerformanceReportTask -Name <name> -ObjectType Controller -ObjectId "0A" -TimeSegment Customer ...`
- `Get-DMPerformanceHistory`
- `Get-DMCapacityHistory`
- `Invoke-DMPerformanceReportTask`
- `Save-DMPerformanceReportFile`
- `Remove-DMPerformanceReportTask`

## Appendix B - REST APIs Reviewed

- `POST /deviceManager/rest/{deviceId}/performance_data`
- `GET /deviceManager/rest/{deviceId}/performance_data`
- `GET /deviceManager/rest/{deviceId}/performance_statistic_switch`
- `GET /deviceManager/rest/{deviceId}/performance_statistic_strategy`
- `POST /api/v2/pms/report_task`
- `GET /api/v2/pms/report_task`
- `GET /api/v2/pms/report_task/export`
- `GET /api/v2/pms/report_task/task_log`
- `GET /api/v2/pms/report_task/file`
- `DELETE /api/v2/pms/report_task/{id}`
- Bond port query APIs documented under the REST reference Bond Port sections.

## Appendix C - Metrics Reviewed

| Friendly Metric | Indicator ID | Notes |
|---|---:|---|
| `QueueLength` | 19 | Live-caveated on System. |
| `UsagePercent` | 18 | Live-caveated on realtime StoragePool; reference table shows port/disk-style applicability, not StoragePool in the visible block table. |
| `TotalIOPS` | 22 | Confirmed. |
| `ReadIOPS` | 25 | Confirmed. |
| `WriteIOPS` | 28 | Confirmed. |
| `BandwidthMBps` | 21 | Confirmed. |
| `ReadBandwidthMBps` | 23 | Confirmed. |
| `WriteBandwidthMBps` | 26 | Confirmed. |
| `AvgLatencyMs` | 370 | Confirmed; converted from microseconds to milliseconds by module. |
| `ReadLatencyMs` | 384 | Confirmed; converted from microseconds to milliseconds by module. |
| `WriteLatencyMs` | 385 | Confirmed; converted from microseconds to milliseconds by module. |
| `CpuUsagePercent` | 68 | Confirmed on System in validation. |
| `Ops` | 182 | Confirmed for FileSystem/NAS. |
| `ReadOps` | 232 | Confirmed for FileSystem/NAS. |
| `WriteOps` | 233 | Confirmed for FileSystem/NAS. |
| `AvgReadOpsResponseTimeUs` | 524 | Confirmed for FileSystem/NAS. |
| `AvgWriteOpsResponseTimeUs` | 525 | Confirmed for FileSystem/NAS. |
| `NasServiceTimeUs` | 523 | Confirmed for FileSystem/NAS. |
