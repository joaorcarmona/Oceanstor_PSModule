# Remote Replication Pairs

## Scope

Lifecycle of LUN-level remote replication pairs (Huawei "HyperReplication"):
create, modify, sync, split, primary/secondary switchover, secondary resource
protection, and deletion. REST resource: `REPLICATIONPAIR`.

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `Get-DMReplicationPair` | `GET REPLICATIONPAIR` / `GET REPLICATIONPAIR/${id}` | Read-only |
| `New-DMReplicationPair` | `POST REPLICATIONPAIR` | Mutating (creates DR relationship) |
| `Set-DMReplicationPair` | `PUT REPLICATIONPAIR/${id}` | Mutating |
| `Remove-DMReplicationPair` | `DELETE REPLICATIONPAIR/${id}` | Mutating (destroys DR relationship) |
| `Sync-DMReplicationPair` | `PUT REPLICATIONPAIR/sync` | Mutating (starts replication) |
| `Split-DMReplicationPair` | `PUT REPLICATIONPAIR/split` | Mutating (stops replication) |
| `Switch-DMReplicationPair` | `PUT REPLICATIONPAIR/switch` | **Failover-class: swaps primary/secondary roles** |
| `Enable-DMReplicationPairSecondaryProtection` | `PUT REPLICATIONPAIR/${id}` (`SECRESACCESS`) | Mutating (changes secondary access) |
| `Disable-DMReplicationPairSecondaryProtection` | `PUT REPLICATIONPAIR/${id}` (`SECRESACCESS`) | Mutating (changes secondary access) |

All mutating cmdlets accept `-Id` or `-Name`, support
`-WhatIf`/`-Confirm`, and declare `ConfirmImpact = 'High'`.

Key `New-DMReplicationPair` parameters: `-LocalLunId`/`-LocalLunName`,
`-RemoteDeviceId`, `-RemoteLunId`/`-RemoteLunName`, `-SynchronizationType`
(`Manual`, `TimedWaitAfterStart`, `TimedWaitAfterSync`, `SpecificTimePolicy`),
`-ReplicationMode` (`Sync`, `Async`), `-RecoveryPolicy` (`Automatic`,
`Manual`), `-Speed` (`Low`, `Medium`, `High`, `Highest`), `-TimingValue`,
`-InitialSyncType` (`AllData`, `WrittenData`), and `-ApiProperties` for raw
request fields. `Sync-DMReplicationPair` supports `-FullCopy`;
`Remove-DMReplicationPair` supports `-ForceDeletePair`.

## Common Workflows

```text
Get-DMRemoteDevice / Get-DMRemoteLun     # resolve targets
New-DMReplicationPair                    # create (starts in a splittable state)
Sync-DMReplicationPair                   # initial or manual synchronization
Split-DMReplicationPair                  # pause replication for maintenance
Switch-DMReplicationPair                 # planned failover / failback (see safety)
Remove-DMReplicationPair                 # tear down
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

# Inventory
Get-DMReplicationPair

# Create an async pair by resolving names to IDs
New-DMReplicationPair -LocalLunName 'app-lun-01' `
    -RemoteDeviceId '0' -RemoteLunName 'app-lun-01-dr' `
    -ReplicationMode Async -RecoveryPolicy Automatic -Speed Medium

# Preview any mutation first
Sync-DMReplicationPair -Name 'app-lun-01' -WhatIf
```

## Safety Notes

- `Switch-DMReplicationPair` changes which array serves the primary copy. Treat
  it as a failover operation; in the integration harness it only runs when
  `Replication.AllowFailover = $true`.
- `Enable/Disable-DMReplicationPairSecondaryProtection` change whether the
  secondary LUN is writable — this affects data-serving behavior at the DR
  site.
- `Split` interrupts replication; the pair stops shipping data until the next
  sync.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-readonly.Tests.ps1` and
  `Tests/Unit/Public/replication-hypermetro-pair-lifecycle.Tests.ps1` cover
  documented endpoints, request bodies, name resolution, `SECRESACCESS`
  values, and the `-WhatIf` path for pair creation.
- Live: `Tests/Integration/Private/Workflows/Replication.ps1` runs an opt-in
  test-owned pair lifecycle (create, read back, sync, split, group
  association, delete) when `Replication.Enabled` and
  `Replication.AllowDrMutation` are set. Switchover is skipped as
  `SkippedUnsafe` unless `Replication.AllowFailover` is also set.

## Known Gaps

- Batch endpoints (`REPLICATIONPAIR/batch`, `sync/batch`, `split/batch`) are
  not wrapped; operate on one pair at a time or loop.
- `REPLICATIONPAIR/transfer` (change replication mode of an existing pair in
  one call) is exposed only through `Set-DMReplicationPair -ReplicationMode`.
- No live switchover validation has been performed yet (requires a dedicated
  DR lab window).

## Related Files

- `POSH-Oceanstor/Public/*DMReplicationPair*.ps1`
- `POSH-Oceanstor/Private/class-OceanstorReplicationPair.ps1`
- `POSH-Oceanstor/Private/Resolve-DMDrPairHelper.ps1`
- `POSH-Oceanstor/Format/OceanstorReplicationPair.format.ps1xml`
