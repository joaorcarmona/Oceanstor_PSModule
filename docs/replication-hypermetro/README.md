# Remote Replication and HyperMetro

POSH-Oceanstor wraps the OceanStor Dorado 6.1.6 disaster-recovery REST surface
with 62 cmdlets covering remote replication (HyperReplication), HyperMetro
active-active, and the NAS/vStore DR tranche.

> **Safety warning.** Most cmdlets in this area change disaster-recovery state:
> replication direction, site priority, secondary access, split/sync state, and
> which array serves production data. Every mutating cmdlet supports
> `-WhatIf`/`-Confirm` and declares `ConfirmImpact = 'High'`. Read
> [safety-and-live-validation.md](safety-and-live-validation.md) before running
> anything other than a `Get-*` cmdlet against a real array.

## SAN versus NAS/vStore scope

- **SAN DR** protects LUNs: remote replication pairs and consistency groups,
  HyperMetro domains, pairs, and consistency groups.
- **NAS/vStore DR** protects file systems and vStores: vStore pairs,
  file-system replication pairs, and file-system HyperMetro domains. These use
  different REST resources and have extra service-impact semantics, so they are
  deliberately separate command families.

## Implemented command families

| Area | Cmdlets | Topic page |
|---|---|---|
| Remote device and LUN discovery | 2 | [remote-devices-and-luns.md](remote-devices-and-luns.md) |
| Remote replication pairs | 9 | [replication-pairs.md](replication-pairs.md) |
| Remote replication consistency groups | 9 | [replication-consistency-groups.md](replication-consistency-groups.md) |
| HyperMetro SAN domains and quorum | 6 | [hypermetro-domains.md](hypermetro-domains.md) |
| HyperMetro pairs | 8 | [hypermetro-pairs.md](hypermetro-pairs.md) |
| HyperMetro consistency groups | 10 | [hypermetro-consistency-groups.md](hypermetro-consistency-groups.md) |
| vStore pairs | 6 | [vstore-pairs.md](vstore-pairs.md) |
| File-system replication | 4 | [file-system-replication.md](file-system-replication.md) |
| File-system HyperMetro domains | 7 | [file-hypermetro-domains.md](file-hypermetro-domains.md) |

## Connecting

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred
```

Add `-SkipCertificateCheck` for lab arrays with self-signed certificates. The
`-WebSession` parameter is optional on every DR cmdlet; when omitted, the most
recent session is used.

## Quick read-only inventory

These commands are read-only and safe to run against production arrays:

```powershell
# What does this array replicate to?
Get-DMRemoteDevice

# Remote LUNs usable as replication or HyperMetro secondaries
Get-DMRemoteLun -RemoteDeviceId '0'
Get-DMRemoteLun -RemoteDeviceId '0' -RemoteServiceType HyperMetroSecondaryLun

# Quorum servers (resolve -QuorumServerId without the DeviceManager UI)
Get-DMQuorumServer

# Current SAN DR state
Get-DMReplicationPair
Get-DMReplicationConsistencyGroup
Get-DMHyperMetroDomain
Get-DMHyperMetroPair
Get-DMHyperMetroConsistencyGroup

# Current NAS/vStore DR state
Get-DMVStorePair
Get-DMFileHyperMetroDomain
```

Each family returns a typed object (for example `OceanstorReplicationPair`)
with friendly status translations plus the raw code properties, and a default
table view.

## Live validation is opt-in

Integration tests for this area are disabled by default. The
`Replication` and `HyperMetro` sections of
`Tests/Integration/IntegrityValidationConfig.psd1` must be explicitly enabled
(with a configured lab remote device, remote LUN, and — for HyperMetro — an
existing domain) before any DR mutation test runs.

Failover-like operations require an additional dedicated flag on top of that:

- `Replication.AllowFailover` gates `Switch-DMReplicationPair` and
  `Switch-DMReplicationConsistencyGroup`.
- `HyperMetro.AllowPrioritySwitch` gates `Switch-DMHyperMetroPairPriority` and
  `Switch-DMHyperMetroConsistencyGroup`.

Without those flags the workflows report the operations as `SkippedUnsafe`
rather than running them. See
[safety-and-live-validation.md](safety-and-live-validation.md).

## Roadmap

Open work for this area is tracked in
[Replication and HyperMetro TODO](TODO.md).
