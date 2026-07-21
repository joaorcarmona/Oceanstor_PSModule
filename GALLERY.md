# POSH-Oceanstor

PowerShell module for managing Huawei OceanStor storage arrays (Dorado **V6**)
through the Device Manager REST API. Earlier (V3) arrays are supported in a
limited way.

## Features

- Inventory and reporting (LUNs, file systems, pools, hosts, hardware, alarms)
- Host, host-group, and initiator (FC / iSCSI / NVMe) management
- Storage provisioning: LUNs, LUN groups, mapping views, file systems, shares
- Data protection: snapshots, remote replication, and HyperMetro workflows
- System configuration: NTP, SNMP, syslog, local users, and roles

## Requirements

- PowerShell 7+
- [ImportExcel](https://www.powershellgallery.com/packages/ImportExcel) (installed automatically)

## Install

```powershell
Install-Module -Name POSH-Oceanstor -Scope CurrentUser
```

## Quick start

```powershell
Connect-deviceManager -Hostname 10.0.0.10
Get-DMlun
Get-DMSystem
```

## Links

- **Project:** https://github.com/joaorcarmona/Oceanstor_PSModule
- **License:** GPL-3.0
