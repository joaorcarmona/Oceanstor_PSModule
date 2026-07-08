# Alarms and Events System Management

> **Status: Partial — alarm/event query, alarm clearing, and alarm-masking
> query/modify, plus system/equipment status. No event-log-only query and no
> alarm-forwarding configuration cmdlets.**

## Scope

Querying array alarms, overall system information, and equipment status.
Alarm notification *transport* (SNMP traps, syslog) is documented in
[snmp.md](snmp.md) and [syslog.md](syslog.md).

## Cmdlets

| Cmdlet | Action | REST resource | Mutating | ShouldProcess |
|---|---|---|---|---:|
| `Get-DMAlarm` | Query current (active) alarms, optionally by time range | `alarm/currentalarm?sortby=startTime,d[&filter=startTime:[start,end]]` | No | — |
| `Get-DMAlarmHistory` | Query historical alarms/events with the full filter surface (level, status, type, object type, sequence, time) | `alarm/historyalarm?sortby=startTime,d[&filter=<clauses>]` | No | — |
| `Get-DMAlarmType` | List the array's alarm object-type catalog (names ↔ numeric values) | `ALARM_DEFINITION_OBJ?language=1` | No | — |
| `Get-DMAlarmMasking` | Query alarm maskings, optionally by level / object type / masked state | `ALARM_DEFINITION?language=1[&filter=<clauses>]` | No | — |
| `Set-DMAlarmMasking` | Enable or disable masking for a specific alarm ID | `ALARM_DEFINITION` (PUT) | Yes | `-Confirm` (Medium) |
| `Get-DMSystem` | Read overall system information | `system/` | No | — |
| `Get-DMEquipmentStatus` | Read equipment/server status (e.g. security mode) | `server/status` | No | — |

Key parameters:

- `Get-DMAlarm` (no filter) — returns all current (active/unrecovered)
  alarms. The `currentalarm` interface does **not** support an
  `alarmStatus` filter; to query cleared/recovered alarms or any historical
  state, use `Get-DMAlarmHistory -AlarmStatus <status>`.
- `Get-DMAlarm -StartTime <datetime> -EndTime <datetime>` — filters
  server-side on a `startTime` range, converted to Unix epoch seconds.
  Either bound may be omitted (defaults to epoch 0 / now respectively).
- `Get-DMAlarm -Last <timespan>` — convenience filter equivalent to
  `-StartTime (Get-Date) - <timespan> -EndTime (Get-Date)`. Cannot be
  combined with `-StartTime`/`-EndTime`.
- `Get-DMAlarmHistory -Level -AlarmStatus -Type -AlarmObjectType -Sequence
  -StartSequence -EndSequence -StartTime/-EndTime/-Last` — all optional,
  AND-combined, mapped server-side to the documented numeric enums.
- `Get-DMAlarmMasking -Level -AlarmObjectType -Masked` — all optional and
  AND-combined server-side to the three documented `ALARM_DEFINITION` filter
  fields (`CMO_ALARM_LEVEL`, `CMO_ALARM_OBJ_TYPE`, `enableClose`). `-Masked
  $true`/`$false` selects only masked / unmasked alarms; `-AlarmObjectType`
  takes a catalog name (see `Get-DMAlarmType`) resolved to its numeric value.
- `Set-DMAlarmMasking -AlarmId <id> -Enable | -Disable` — turns masking on
  (`enableClose = true`) or off (`enableClose = false`) for one alarm. `-Enable`
  and `-Disable` are mutually exclusive and one is required. Pipeline-aware:
  `Get-DMAlarmMasking | Set-DMAlarmMasking -Disable` flows the alarm ID and
  session through. Supports `-WhatIf`/`-Confirm` (Medium).

`Get-DMAlarm` and `Get-DMAlarmHistory` return `OceanStorAlarm` objects;
`Get-DMAlarmType` returns objects with `Name`/`ObjectType`/`Id`;
`Get-DMAlarmMasking` returns `OceanStorAlarmMasking` objects (`Alarm Id`,
`Name`, `Level`, `Alarm Object Type`, `Masked`, `Uncleared Alarm Exists`);
`Get-DMSystem` returns `OceanStorSystem`; `Get-DMEquipmentStatus` returns a
status object with `Status`, `StatusName` (e.g. `SecurityMode`), and
`Description`.

## Common Workflows

1. **Health check** — read system info, equipment status, and unrecovered
   alarms in one pass.
2. **Alarm reporting** — export unrecovered alarms for ticketing or
   compliance evidence.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Health check
Get-DMSystem -WebSession $storage
Get-DMEquipmentStatus -WebSession $storage
Get-DMAlarm -WebSession $storage

# Current-alarm evidence export (local file only)
Get-DMAlarm -WebSession $storage |
    Export-Csv -Path .\current-alarms.csv -NoTypeInformation

# Current alarms generated in the last 24 hours
Get-DMAlarm -WebSession $storage -Last (New-TimeSpan -Hours 24)

# Current alarms generated in an explicit date range
Get-DMAlarm -WebSession $storage -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date)

# Cleared/recovered or historical alarms (use the history cmdlet)
Get-DMAlarmHistory -WebSession $storage -AlarmStatus Cleared

# List which alarms are currently masked
Get-DMAlarmMasking -WebSession $storage -Masked $true

# Mask every informational alarm (prompts for confirmation)
Get-DMAlarmMasking -WebSession $storage -Level Info | Set-DMAlarmMasking -Enable

# Unmask a specific alarm by ID
Set-DMAlarmMasking -WebSession $storage -AlarmId 64425164820 -Disable
```

## Safety Notes

- All read cmdlets are `ReadOnlySystemManagement` — safe to run live at any
  time. `Get-DMSystem`/`Get-DMEquipmentStatus` passed live validation on
  2026-07-07. `Get-DMAlarm` has since been repointed from `historyalarm` to
  `currentalarm` (see Related Files) and should be re-validated live.
- When acknowledge/clear cmdlets are eventually implemented, they must be
  classified `AlertingOrMonitoringMutation` and never run against
  pre-existing alarms in live validation.
- `Set-DMAlarmMasking` is a monitoring-configuration mutation
  (`AlertingOrMonitoringMutation`): it changes whether an alarm is suppressed.
  The change is reversible (re-run with the opposite `-Enable`/`-Disable`
  switch), but it must not be run against a production array during live
  validation without an explicit rollback plan for the affected alarm IDs.

## Integrity Test Coverage

- Read-only: `Get-DMSystem` and `Get-DMAlarm` are validated by
  `ReadValidation.ps1`. `Get-DMEquipmentStatus` is **not yet registered**
  there and falls through the coverage fallback.
- Unit tests: `Get-SystemConfiguration.Tests.ps1` covers
  `Get-DMEquipmentStatus`; `Get-DMSystem` and `Get-DMAlarm` are covered by
  the older suites (`Get-Storage.Tests.ps1` / hardware-network suites).
- Unit tests: `Get-DMAlarmMasking.Tests.ps1` and `Set-DMAlarmMasking.Tests.ps1`
  cover the masking query (filter mapping, object-type resolution, output
  shaping) and modify (PUT body, `-Enable`/`-Disable`, `-WhatIf`, pipeline)
  cmdlets.

## Known Gaps

- No alarm acknowledge/clear cmdlets (`UnsupportedFeatureGap`).
- No event-log query cmdlet (`Get-DMEvent` does not exist)
  (`UnsupportedFeatureGap`).
- `Get-DMEquipmentStatus` missing from read-only integrity validation
  (`IntegrityTestGap`).
- `Get-DMAlarmMasking`/`Set-DMAlarmMasking` not yet exercised by live
  integrity validation (`IntegrityTestGap`). The `ALARM_DEFINITION` filter
  operator syntax follows the module's `field::value` convention (as used by
  `Get-DMAlarmHistory`) and should be confirmed against a live array.

## Related Files

- `POSH-Oceanstor/Public/Get-DMAlarm.ps1`, `Get-DMAlarmHistory.ps1`,
  `Get-DMAlarmType.ps1`, `Get-DMAlarmMasking.ps1`, `Set-DMAlarmMasking.ps1`,
  `Get-DMSystem.ps1`, `Get-DMEquipmentStatus.ps1`
- `POSH-Oceanstor/Private/class-OceanStorAlarmMasking.ps1`
- `Tests/Unit/Public/Get-Hardware.Tests.ps1` (covers `Get-DMAlarm`),
  `Get-DMAlarmHistory.Tests.ps1`, `Get-DMAlarmType.Tests.ps1`,
  `Get-DMAlarmMasking.Tests.ps1`, `Set-DMAlarmMasking.Tests.ps1`,
  `Get-SystemConfiguration.Tests.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
