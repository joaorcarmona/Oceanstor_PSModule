# Huawei Oceanstor_PSModule

[![PowerShell CI](https://github.com/joaorcarmona/Oceanstor_PSModule/actions/workflows/powershell.yml/badge.svg)](https://github.com/joaorcarmona/Oceanstor_PSModule/actions/workflows/powershell.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/POSH-Oceanstor?logo=powershell&logoColor=white&label=PS%20Gallery)](https://www.powershellgallery.com/packages/POSH-Oceanstor)
[![PS Gallery Downloads](https://img.shields.io/powershellgallery/dt/POSH-Oceanstor?logo=powershell&logoColor=white&label=downloads)](https://www.powershellgallery.com/packages/POSH-Oceanstor)
[![License: GPL v3](https://img.shields.io/github/license/joaorcarmona/Oceanstor_PSModule)](https://github.com/joaorcarmona/Oceanstor_PSModule/blob/master/LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/joaorcarmona/Oceanstor_PSModule?include_prereleases&sort=semver)](https://github.com/joaorcarmona/Oceanstor_PSModule/releases)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Last Commit](https://img.shields.io/github/last-commit/joaorcarmona/Oceanstor_PSModule)](https://github.com/joaorcarmona/Oceanstor_PSModule/commits/master)

Oceanstor PowerShell Module, is a module to operate with Huawei Oceanstor devices (v6) - Previous versions should work in limited way. Please report any bugs.

Current module version: 1.0.0

The module includes commands for inventory, reporting, host and initiator
management, storage-resource creation, mapping-view operations, snapshot
management, remote replication and HyperMetro SAN workflows, and array system
configuration such as NTP, SNMP, syslog, local users, and roles.

## How to Install

Requires **PowerShell 7+**. The module depends on **ImportExcel**.

### From the PowerShell Gallery (recommended)

```powershell
# Install for the current user (no admin rights required).
Install-Module -Name POSH-Oceanstor -Scope CurrentUser

# ...or system-wide (run from an elevated session).
Install-Module -Name POSH-Oceanstor -Scope AllUsers

# Update to the latest release later.
Update-Module -Name POSH-Oceanstor
```

`Install-Module` pulls in the required **ImportExcel** dependency automatically.

### Manual install

```powershell
# 1. Download the latest release from GitHub:
#    https://github.com/joaorcarmona/Oceanstor_PSModule/releases
# 2. Unzip it.
# 3. Copy the POSH-Oceanstor folder into one of your module paths:
#      Current user: $HOME\Documents\PowerShell\Modules\POSH-Oceanstor
#      System wide : C:\Program Files\PowerShell\Modules\POSH-Oceanstor

# The manual method does not resolve dependencies, so install ImportExcel yourself:
Install-Module -Name ImportExcel -Scope CurrentUser
```

### Import and get started

```powershell
# Import the module.
Import-Module -Name POSH-Oceanstor

# List the module's commands.
Get-Command -Module POSH-Oceanstor

# Read the module help.
Get-Help about_POSH-Oceanstor
```

## Feature modules

Commands are grouped into **features**. Most features are enabled by default, but the two
data-protection features whose live validation needs a second array or quorum server —
**HyperMetro** and **Replication** — ship **disabled**. A disabled feature's commands are
simply not exported, so `Get-Command -Module POSH-Oceanstor` and tab-completion do not show
them until you enable the feature and re-import the module.

> ⚠️ **HyperMetro and Replication are still in development and are not yet fully validated
> against real disaster-recovery hardware. Treat them as experimental / not production
> ready** — that is why they ship disabled. See
> [docs/feature-modules/README.md](docs/feature-modules/README.md) for full details.

| Feature | Default | Contents |
|---|---|---|
| `Core` | always on (locked) | Connect/Disconnect, `Get-DMSystem`, exports, and the `*-DMFeature` cmdlets |
| `HyperMetro` | **off** | HyperMetro domains/pairs/consistency-groups and quorum servers |
| `Replication` | **off** | remote replication pairs/consistency-groups, vStore pairs, remote device/LUN |
| `Host` | on | hosts, host groups, FC/iSCSI/NVMe initiators, host links |
| `Lun` | on | LUN CRUD, LUN groups, workload types |
| `Mapping` | on | mapping views, port groups, map/unmap commands |
| `Snapshot` | on | LUN snapshots, snapshot consistency groups, HyperCDP schedules |
| `Protection` | on | protection groups |
| `QoS` | on | QoS policies and associations |
| `FileSystem` | on | file systems, FS snapshots, dTrees, quotas, CIFS/NFS shares & clients, vStores |
| `Network` | on | ETH/FC/SAS ports, VLANs, LIFs, bonds, failover groups, DNS, LLDP |
| `Hardware` | on | disks, enclosures, controllers, BBUs, interface modules, equipment status |
| `StoragePool` | on | storage pool getters and rename |
| `Performance` | on | performance counters, capacity history, monitoring, report tasks |
| `SystemManagement` | on | alarms, certificates, local users, roles, SNMP, NTP, syslog, timezone/UTC |

```powershell
# See every feature, its configured state, and how many commands it groups.
Get-DMFeature

# Enable HyperMetro, then re-import so its commands become available in this session.
Enable-DMFeature -Name HyperMetro
Import-Module POSH-Oceanstor -Force

# Disable it again (removes the override).
Disable-DMFeature -Name HyperMetro
Import-Module POSH-Oceanstor -Force
```

Enabling or disabling a feature records the change in a per-user config file at
`%APPDATA%\POSH-Oceanstor\ModuleConfig.json` (only overrides that differ from the built-in
defaults are stored). The change does **not** affect the current session — you must run
`Import-Module POSH-Oceanstor -Force`, or start a new session, for the export list to change.
Set `$env:POSH_OCEANSTOR_CONFIG_PATH` to redirect the config file (used by labs and CI).

### Examples

The module is a PowerShell module to interact with Huawei OceanStor devices through the REST API. All commands are designed to work without extra arguments unless you are filtering results. The WebSession parameter is optional on all commands. If you are querying multiple storage systems at the same time, pass the WebSession object returned by Connect-deviceManager.

To start, it is necessary to connect to a storage system.
```powershell
# Connect to a storage. By default, PowerShell securely prompts for your credentials.
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru

# The -Secure switch remains available for the interactive prompt form.
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru -Secure

# For unattended operation, provide a PSCredential obtained from a secure source.
# For example, import an encrypted credential exported for the same user and machine.
$credential = Import-Clixml -Path "$HOME\.oceanstor\device-manager.credential.xml"
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru -Credential $credential

# A SecureString password may also be paired with a user name.
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru -LoginUser "username" -LoginPwd $securePassword
```
Next the user can Query any command without requiring the input the username again.
```powershell
#Query all storage luns
$luns = Get-DMlun
```

For multiple storage systems, use the WebSession parameter:
```powershell
# Connect to two storages and save each WebSession in a different variable.
$storage1 = Connect-deviceManager -Hostname "10.0.0.1" -PassThru
$storage2 = Connect-deviceManager -Hostname "10.0.0.2" -PassThru
```
Next, query any command without re-entering credentials, but pass the WebSession parameter explicitly:
```powershell
# Query all storage LUNs
$storage1luns = Get-DMlun -WebSession $storage1
$storage2luns = Get-DMlun -WebSession $storage2
```

#### Export Storage Configuration to Excel
```powershell
# Connect to a storage (PowerShell securely prompts for credentials).
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru

#export all storage data to excel
Export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx" -IncludeObject full

#export some properties to excel (can be chosen multiple from: "luns","system","configuration","hostgroups","lungroups","disks","hosts","vstores","storagepools","performance")
Export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx" -IncludeObject luns, lungroups

#export array configuration audit data such as NTP, SNMP, syslog, users, and roles
Export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx" -IncludeObject configuration

#export live performance samples for system/controllers/pools/disks/hosts/LUNs alongside the rest ("performance" is opt-in only, never implied by "full")
Export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx" -IncludeObject full, performance
```

#### Array System Configuration
```powershell
# Review NTP, SNMP, syslog, local users, and roles.
Get-DMNtpServer -WebSession $storage
Get-DMSnmpConfig -WebSession $storage
Get-DMSnmpTrapServer -WebSession $storage
Get-DMSyslogNotification -WebSession $storage
Get-DMLocalUser -WebSession $storage
Get-DMRole -WebSession $storage
```

#### Performance Monitoring
```powershell
# Connect to a storage (PowerShell securely prompts for credentials).
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru

# Enable performance monitoring on the array, then poll current (real-time) samples.
Enable-DMPerformanceMonitoring -WebSession $storage
Get-DMPerformance -WebSession $storage -ObjectType LUN -ObjectId '1'

# Friendly wrappers are also available per object type.
Get-DMLunPerformance -WebSession $storage -ObjectId '1'
Get-DMControllerPerformance -WebSession $storage

# The performance_data endpoint only ever returns the current sample. For historical/ranged
# queries, Get-DMPerformanceHistory drives the pms/report_task workflow (create, run, download,
# parse) and cleans up after itself, returning OceanStor.PerformanceSample objects.
Get-DMPerformanceHistory -WebSession $storage -ObjectType LUN -ObjectId '1' -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
```
The underlying report-task lifecycle (New-/Get-/Remove-DMPerformanceReportTask, Invoke-DMPerformanceReportTask, Save-DMPerformanceReportFile) is also exported directly for callers who need finer-grained control than Get-DMPerformanceHistory provides.

#### Remote Replication and HyperMetro
```powershell
# Discover remote DR objects.
Get-DMRemoteDevice -WebSession $storage
Get-DMRemoteLun -WebSession $storage -RemoteDeviceId 'remote-array-id'

# Remote replication pairs and consistency groups.
$pair = New-DMReplicationPair -WebSession $storage -LocalLunId 'local-lun-id' `
    -RemoteDeviceId 'remote-array-id' -RemoteLunId 'remote-lun-id' `
    -ReplicationMode Async -SynchronizationType Manual
Sync-DMReplicationPair -WebSession $storage -Id $pair.Id

$group = New-DMReplicationConsistencyGroup -WebSession $storage -Name 'replication-cg' `
    -RemoteDeviceId 'remote-array-id'
Add-DMReplicationPairToConsistencyGroup -WebSession $storage -GroupId $group.Id -PairId $pair.Id

# SAN HyperMetro domains can be created directly or bound to a quorum server.
Get-DMHyperMetroDomain -WebSession $storage
$domain = New-DMHyperMetroDomain -WebSession $storage -Name 'metro-domain' `
    -RemoteDevices @(@{ devId = 'remote-array-id'; devESN = 'remote-array-sn'; devName = 'remote-array' })
Add-DMQuorumServerToHyperMetroDomain -WebSession $storage -Id $domain.Id -QuorumServerId 'quorum-server-id'

# HyperMetro pairs and consistency groups use a SAN HyperMetro domain.
$metroPair = New-DMHyperMetroPair -WebSession $storage -DomainId 'domain-id' `
    -LocalLunId 'local-lun-id' -RemoteLunId 'remote-lun-id' -FirstSync
Sync-DMHyperMetroPair -WebSession $storage -Id $metroPair.Id

# NAS/vStore DR uses distinct wrappers so it is not confused with SAN LUN flows.
Get-DMVStorePair -WebSession $storage -ReplicationType RemoteReplication
$vstorePair = New-DMVStorePair -WebSession $storage -LocalVStoreId '1' `
    -RemoteVStoreId '1' -ReplicationType RemoteReplication -RemoteDeviceId '0'
Sync-DMVStorePair -WebSession $storage -Id $vstorePair.Id

Get-DMFileHyperMetroDomain -WebSession $storage
```

#### Search one lun by WWN
```powershell
# Connect to a storage (PowerShell securely prompts for credentials).
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru

#Search for a lun by Lun WWN
 $luns = Get-DMlunByWWN -WebSession $storage -wwn "6a08cf810075766e1efc050700000005"
```

## Additional Resources

NOTE: This Module have been modified to support Powershell version 6 and 7. Previous version will not work.

### Links

- [OceanStor V3 V300R006C50 REST Interface Reference] (https://support.huawei.com/enterprise/en/doc/EDOC1100136666)
- [OceanStor Dorado 6.1.6 REST Interface Reference] (https://support.huawei.com/enterprise/en/doc/EDOC1100324309)
