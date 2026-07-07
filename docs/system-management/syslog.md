# Syslog System Management

## Scope

Syslog notification settings (format, severity, transport) and the list of
syslog servers the array forwards to.

## Cmdlets

| Cmdlet | Action | REST resource | Mutating | ShouldProcess |
|---|---|---|---|---:|
| `Get-DMSyslogNotification` | Read syslog notification settings and server list | `syslog` | No | — |
| `Set-DMSyslogNotification` | Modify global syslog notification settings | `syslog` (PUT) | Yes | Yes |
| `Add-DMSyslogServer` | Add a syslog server address | `syslog_addip` (POST) | Yes | Yes |
| `Remove-DMSyslogServer` | Remove a syslog server address | `syslog_removeip` (DELETE) | Yes | Yes |

Key parameters:

- `Add-DMSyslogServer -Address <string> [-Property]`
- `Remove-DMSyslogServer -Address <string> [-Property]`
- `Set-DMSyslogNotification -Property <hashtable>` — passes REST fields such
  as format and severity directly.

`Get-DMSyslogNotification` returns an `OceanStorSyslogNotification` typed
object including the `Server Addresses` list.

## Common Workflows

1. **Audit forwarding** — read the notification settings and target list.
2. **Add a collector** — add a new syslog server address alongside the
   existing ones.
3. **Retire a collector** — remove a specific address you added.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Audit current syslog forwarding
Get-DMSyslogNotification -WebSession $storage

# Add a new collector (preview first)
Add-DMSyslogServer -WebSession $storage -Address '192.0.2.20' -WhatIf
Add-DMSyslogServer -WebSession $storage -Address '192.0.2.20'

# Remove ONLY the address you added
Remove-DMSyslogServer -WebSession $storage -Address '192.0.2.20'
```

## Safety Notes

- `Set-DMSyslogNotification` is `GlobalSettingMutation` /
  `AlertingOrMonitoringMutation`: it rewrites array-wide forwarding behavior.
  Do not run it live on a shared array.
- `Add-DMSyslogServer` / `Remove-DMSyslogServer` operate on **addresses**,
  not IDs. A test-owned lifecycle is possible (add a unique unused address,
  then remove exactly that address) but carries more risk than SNMP trap
  targets because removal is by value: a typo or duplicate address could
  remove a production target. Any future integration workflow must record
  the exact address it added and remove only that.
- Do not disable syslog forwarding or replace existing targets.

## Integrity Test Coverage

- Read-only: `Get-DMSyslogNotification` is validated by `ReadValidation.ps1`.
- Mutating: no integration workflow. The three mutators are reported as
  `SkippedUnsafe` in every run.
- Unit tests: `Set-SystemConfiguration.Tests.ps1` covers notification set and
  server add/remove.

## Known Gaps

- No test-owned integration workflow for add/remove of a syslog address
  (`IntegrityTestGap`, second-priority after SNMP because removal is
  by-address rather than by-ID).
- Severity/facility/port shaping is exposed only through the generic
  `-Property` hashtable, not named parameters (`ImplementationImprovement`).

## Related Files

- `POSH-Oceanstor/Public/Get-DMSyslogNotification.ps1`,
  `Set-DMSyslogNotification.ps1`, `Add-DMSyslogServer.ps1`,
  `Remove-DMSyslogServer.ps1`
- `Tests/Unit/Public/Set-SystemConfiguration.Tests.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
