# System Management Documentation

This folder documents the **system / array management** domain of POSH-Oceanstor:
cmdlets whose purpose is to inspect or configure global storage-array behavior
rather than storage objects (LUNs, file systems, hosts).

## Domains

| Document | Domain | Implemented? |
|---|---|---|
| [local-users-and-roles.md](local-users-and-roles.md) | Local users, roles, role permissions | Yes |
| [snmp.md](snmp.md) | SNMP protocol config, security policy, community, trap servers, USM users | Yes |
| [ntp.md](ntp.md) | NTP servers, NTP status, time zone, UTC time | Yes |
| [syslog.md](syslog.md) | Syslog notification settings and syslog servers | Yes |
| [dns.md](dns.md) | DNS server configuration | Yes |
| [certificates.md](certificates.md) | Certificate management | Partial (read-only inventory: `Get-DMCertificate`; mutation not implemented) |
| [alarms-and-events.md](alarms-and-events.md) | Alarm queries; system and equipment status | Partial (read-only) |
| [safety-and-live-validation.md](safety-and-live-validation.md) | Safety classification and live-validation rules | — |
| [TODO.md](TODO.md) | Roadmap and open gaps for this domain | — |

## Connecting

All examples in this folder assume a connected DeviceManager session:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru
# Lab arrays with self-signed certificates: add -SkipCertificateCheck
```

The `-WebSession` parameter is optional when only one array session is active;
pass it explicitly when working with multiple arrays.

## Conventions in this domain

- Every mutating cmdlet supports `SupportsShouldProcess` — `-WhatIf` and
  `-Confirm` work everywhere.
- Every cmdlet accepts pipeline input for its identity parameter.
- Getters return typed output classes (`OceanStorSnmpConfig`,
  `OceanStorLocalUser`, `OceanStorNtpConfig`, …) defined in
  `POSH-Oceanstor/Private/class-OceanStorSystemConfiguration.ps1`.
- System configuration (NTP, SNMP config/security/trap servers/USM users,
  syslog, local users, roles) is included in the Excel inventory export
  (`Export-DMStorageToExcel`).

## Safety in one paragraph

System-management mutators change **global array behavior** — monitoring,
alerting, time sync, name resolution, and authentication. Unlike LUN or host
mutations, a mistake here can silently break production alerting or lock out
administrators. Read the
[safety-and-live-validation.md](safety-and-live-validation.md) rules before
running any `Set-`/`New-`/`Remove-` cmdlet in this domain against a shared
array.
