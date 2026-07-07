# Alarms and Events System Management

> **Status: Partial — read-only alarm query plus system/equipment status.
> No acknowledge/clear, no event log query, no alarm-forwarding
> configuration cmdlets.**

## Scope

Querying array alarms, overall system information, and equipment status.
Alarm notification *transport* (SNMP traps, syslog) is documented in
[SNMP.md](SNMP.md) and [SYSLOG.md](SYSLOG.md).

## Cmdlets

| Cmdlet | Action | REST resource | Mutating | ShouldProcess |
|---|---|---|---|---:|
| `Get-DMAlarm` | Query alarms filtered by status | `alarm/historyalarm?filter=alarmStatus::<status>` | No | — |
| `Get-DMSystem` | Read overall system information | `system/` | No | — |
| `Get-DMEquipmentStatus` | Read equipment/server status (e.g. security mode) | `server/status` | No | — |

Key parameters:

- `Get-DMAlarm -AlarmStatus <status>` — e.g. `Unrecovered`; filters
  server-side on alarm status.

`Get-DMAlarm` returns `OceanStorAlarm` objects; `Get-DMSystem` returns
`OceanStorSystem`; `Get-DMEquipmentStatus` returns a status object with
`Status`, `StatusName` (e.g. `SecurityMode`), and `Description`.

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
Get-DMAlarm -WebSession $storage -AlarmStatus Unrecovered

# Alarm evidence export (local file only)
Get-DMAlarm -WebSession $storage -AlarmStatus Unrecovered |
    Export-Csv -Path .\unrecovered-alarms.csv -NoTypeInformation
```

## Safety Notes

- All three cmdlets are `ReadOnlySystemManagement` — safe to run live at any
  time. All three passed live validation on 2026-07-07 (`Get-DMAlarm
  -AlarmStatus Unrecovered`: 3 alarms in ~150 ms on the lab array).
- When acknowledge/clear cmdlets are eventually implemented, they must be
  classified `AlertingOrMonitoringMutation` and never run against
  pre-existing alarms in live validation.

## Integrity Test Coverage

- Read-only: `Get-DMSystem` and `Get-DMAlarm` are validated by
  `ReadValidation.ps1`. `Get-DMEquipmentStatus` is **not yet registered**
  there and falls through the coverage fallback.
- Unit tests: `Get-SystemConfiguration.Tests.ps1` covers
  `Get-DMEquipmentStatus`; `Get-DMSystem` and `Get-DMAlarm` are covered by
  the older suites (`Get-Storage.Tests.ps1` / hardware-network suites).

## Known Gaps

- No alarm acknowledge/clear cmdlets (`UnsupportedFeatureGap`).
- No event-log query cmdlet (`Get-DMEvent` does not exist)
  (`UnsupportedFeatureGap`).
- No date/range filtering on `Get-DMAlarm`; only status filtering
  (`ImplementationImprovement`).
- `Get-DMEquipmentStatus` missing from read-only integrity validation
  (`IntegrityTestGap`).

## Related Files

- `POSH-Oceanstor/Public/Get-DMAlarm.ps1`, `Get-DMSystem.ps1`,
  `Get-DMEquipmentStatus.ps1`
- `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
