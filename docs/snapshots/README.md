# Snapshots Documentation

This folder documents POSH-Oceanstor snapshot cmdlets for LUN snapshots,
file-system snapshots, snapshot consistency groups, snapshot copies,
protection-group relationships, and HyperCDP schedules.

## Documentation Map

| Document | Domain | Implemented? |
|---|---|---|
| [lun-snapshots.md](lun-snapshots.md) | LUN snapshot lifecycle and actions | Yes |
| [file-system-snapshots.md](file-system-snapshots.md) | File-system snapshot lifecycle and restore | Yes |
| [snapshot-consistency-groups.md](snapshot-consistency-groups.md) | Snapshot consistency groups | Yes |
| [snapshot-copies.md](snapshot-copies.md) | LUN snapshot and consistency-group copies | Yes |
| [protection-groups.md](protection-groups.md) | Protection-group relationship | Yes |
| [snapshot-schedules.md](snapshot-schedules.md) | HyperCDP schedules | Yes, block HyperCDP |
| [safety-and-live-validation.md](safety-and-live-validation.md) | Safety rules for live arrays | - |
| [CHANGELOG.md](../../CHANGELOG.md) | Consolidated changelog — completed work, deferred items, safety reference | - |

## Connecting

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru
# Lab arrays with self-signed certificates: add -SkipCertificateCheck
```

## Quick Read-Only Inventory

```powershell
Get-DMLunSnapshot -WebSession $storage
Get-DMFileSystemSnapshot -WebSession $storage -FileSystemName 'fs01'
Get-DMSnapshotConsistencyGroup -WebSession $storage
Get-DMHyperCDPSchedule -WebSession $storage
```

## Compact Inventory Views

Read-only `Select-Object` projections for snapshot audits. Field names are the
friendly properties surfaced on the typed objects (multi-word names are quoted);
adjust the columns to the report you need. None of these mutate the array.

```powershell
# LUN-snapshot inventory
Get-DMLunSnapshot -WebSession $storage |
    Select-Object Name, Id, WWN, 'Source Lun Name', 'Health Status', 'Running Status', 'User Capacity'

# File-system snapshot inventory (scoped to a parent file system)
Get-DMFileSystemSnapshot -WebSession $storage -FileSystemName 'fs01' |
    Select-Object Name, Id, 'Source File System Name', 'Snapshot Type', 'Health Status', Timestamp

# Snapshot consistency-group inventory
Get-DMSnapshotConsistencyGroup -WebSession $storage |
    Select-Object Name, Id, 'Running Status', 'Protection Group Name', Timestamp

# HyperCDP schedule inventory (spot enabled-but-idle schedules)
Get-DMHyperCDPSchedule -WebSession $storage |
    Select-Object Name, Id, Enabled, 'Running Status', 'Schedule Type', 'Last Execution Result'
```

Keep the stable `Id` column in any export you plan to feed back into an
automation step — names are for readers, IDs are for machines.

## Coverage Overview

LUN snapshots, file-system snapshots, snapshot consistency groups, snapshot
copies, restore actions, resize/restart actions, and non-secure HyperCDP
schedule cmdlets are implemented. Broader snapshot policy/schedule families
outside HyperCDP were not found in this cmdlet surface.

## Safety in One Paragraph

Snapshots are recovery points. Creating snapshots is usually safer than
deleting or restoring them, but restore/rollback can overwrite live data and
deletion removes recovery options. Use `-WhatIf` for mutators and run live
tests only against test-owned LUNs, file systems, and snapshots.
