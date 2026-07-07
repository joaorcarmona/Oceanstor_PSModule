# File-System Replication

## Scope

Remote replication for file systems: creating file-system replication pairs
(the same `REPLICATIONPAIR` resource as SAN, with `LOCALRESTYPE = 40`) and
controlling secondary-side write access. Once created, a file-system pair is
managed with the same pair lifecycle cmdlets as SAN replication
(`Get/Set/Remove/Sync/Split/Switch-DMReplicationPair`).

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `New-DMFileSystemReplicationPair` | `POST REPLICATIONPAIR` (`LOCALRESTYPE = 40`) | Mutating (creates DR relationship) |
| `Enable-DMFileSystemReplicationPairSecondaryProtection` | `PUT SET_SECONDARY_WRITE_LOCK` | Mutating (locks secondary writes) |
| `Disable-DMFileSystemReplicationPairSecondaryProtection` | `PUT CANCEL_SECONDARY_WRITE_LOCK` | Mutating (unlocks secondary writes) |
| `Set-DMFileSystemReplicationPairSecondaryReadOnly` | `PUT SET_SECONDARY_FILESYSTEM_READ_ONLY` | Mutating (changes secondary access) |

`New-DMFileSystemReplicationPair` requires `-LocalFileSystemId`,
`-RemoteDeviceId`, and `-RemoteFileSystemId`; optional `-SynchronizationType`,
`-ReplicationMode`, `-RecoveryPolicy`, `-Speed`, `-VStorePairId`, `-VstoreId`,
`-TimingValue`, `-ApiProperties`. The secondary-protection cmdlets take the
pair `-Id` and optional `-VstoreId`.

## Common Workflows

```text
Get-DMFileSystem                             # resolve the local file system ID
New-DMFileSystemReplicationPair              # create the pair
Sync-DMReplicationPair / Split-DMReplicationPair   # shared pair lifecycle
Enable-DMFileSystemReplicationPairSecondaryProtection   # protect DR copy
Set-DMFileSystemReplicationPairSecondaryReadOnly        # expose DR copy read-only
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

$fs = Get-DMFileSystem -Name 'shared-data'
New-DMFileSystemReplicationPair -LocalFileSystemId $fs.Id `
    -RemoteDeviceId '0' -RemoteFileSystemId '42' -ReplicationMode Async -WhatIf
```

## Safety Notes

- Secondary write-lock and read-only changes directly alter what NAS clients
  at the DR site can do with the data. Coordinate with share-level access
  before changing them.
- File-system pairs ride on the same `REPLICATIONPAIR` lifecycle: a `Switch`
  on a file-system pair is a NAS failover.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-nas-vstore.Tests.ps1`
  verifies the `LOCALRESTYPE = 40` create body and all three
  secondary-protection endpoints.
- Live: no gated integration workflow yet (needs a lab remote file system).

## Known Gaps

- No dedicated `Get-` wrapper filtered to file-system pairs;
  `Get-DMReplicationPair` returns both LUN and file-system pairs.
- No integration workflow for file-system pair lifecycle.

## Related Files

- `POSH-Oceanstor/Public/New-DMFileSystemReplicationPair.ps1`
- `POSH-Oceanstor/Public/Enable-DMFileSystemReplicationPairSecondaryProtection.ps1`
- `POSH-Oceanstor/Public/Disable-DMFileSystemReplicationPairSecondaryProtection.ps1`
- `POSH-Oceanstor/Public/Set-DMFileSystemReplicationPairSecondaryReadOnly.ps1`
