# NTP and Time System Management

## Scope

NTP client configuration and status, array time zone, and array UTC time.

## Cmdlets

| Cmdlet | Action | REST resource | Mutating | ShouldProcess |
|---|---|---|---|---:|
| `Get-DMNtpServer` | Read NTP client configuration | `ntp_client_config` | No | — |
| `Get-DMNtpStatus` | Read NTP sync status and connected server | `ntp_client_config/get_ntp_status` | No | — |
| `Set-DMNtpServer` | Set NTP servers / sync period / auth / enablement | `ntp_client_config` (PUT) | Yes | Yes |
| `Test-DMNtpServer` | Check connectivity to an NTP server address | `check_ntp_server_address_connective` (PUT) | Probe only | No |
| `Get-DMTimeZone` | Read array time zone and DST setting | `system_timezone` | No | — |
| `Set-DMTimeZone` | Set array time zone | `system_timezone` (PUT) | Yes | Yes |
| `Get-DMutcTime` | Read array UTC time (epoch + DateTime) | `system_utc_time` | No | — |
| `Set-DMutcTime` | Set array UTC time | `system_utc_time` (PUT) | Yes | Yes |

Key parameters:

- `Set-DMNtpServer -Address <string[]> [-Disabled] [-SyncPeriod] [-AuthenticationEnabled] [-Property]`
  — accepts IPv4, IPv6, and FQDN addresses; malformed addresses are rejected
  by parameter validation (unit-tested).
- `Set-DMTimeZone -TimeZoneName <string>`
- `Set-DMutcTime -UtcTime <epoch seconds>`

Getters return `OceanStorNtpConfig`, `OceanStorNtpStatus`, and time-zone/UTC
result objects.

## Common Workflows

1. **Audit time sync** — read NTP config, confirm status shows a connected
   server, verify time zone.
2. **Point the array at new NTP servers** — test connectivity first, then set.
3. **Manual time set** — only for arrays where NTP is disabled.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Audit
Get-DMNtpServer -WebSession $storage
Get-DMNtpStatus -WebSession $storage
Get-DMTimeZone -WebSession $storage
Get-DMutcTime -WebSession $storage

# Verify a candidate NTP server is reachable from the array
Test-DMNtpServer -WebSession $storage -Address 'ntp1.example.internal'

# Replace the NTP server list (always preview on shared arrays)
Set-DMNtpServer -WebSession $storage -Address 'ntp1.example.internal', 'ntp2.example.internal' -WhatIf
```

## Safety Notes

- `Set-DMNtpServer`, `Set-DMTimeZone`, and `Set-DMutcTime` are
  `GlobalSettingMutation`: NTP configuration is a **single global setting**,
  not a collection of discrete objects — "adding" a server means rewriting
  the whole list. There is no test-owned variant. Do not run these live
  unless the previous values are captured and a rollback is planned.
- Skewing array time can break certificate validation, replication
  scheduling, log correlation, and alarm timestamps.
- `Test-DMNtpServer` only probes connectivity and does not change
  configuration; it is safe to run against servers you own.

## Integrity Test Coverage

- Read-only: `Get-DMNtpServer`, `Get-DMNtpStatus`, `Get-DMTimeZone`, and
  `Get-DMutcTime` are all validated by `ReadValidation.ps1`.
- Mutating: intentionally no workflow — these are global settings. The
  mutators (including `Set-DMTimeZone` and `Set-DMutcTime`) are reported as
  `SkippedUnsafe` in every run.
- Unit tests: `Get/Set-SystemConfiguration.Tests.ps1` cover config reads,
  status reads, sets, address validation, time zone, and UTC time.

## Known Gaps

- `Get-DMTimeZone` / `Get-DMutcTime` missing from read-only integrity
  validation (`IntegrityTestGap`).
- No dedicated NTP enable/disable cmdlet beyond `Set-DMNtpServer -Disabled`
  (adequate; documented for clarity).

## Related Files

- `POSH-Oceanstor/Public/*DMNtp*.ps1`, `*DMTimeZone*.ps1`, `*DMutcTime*.ps1`
- `POSH-Oceanstor/Private/class-OceanStorSystemConfiguration.ps1`
- `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1`
- `Tests/Unit/Public/Set-SystemConfiguration.Tests.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
