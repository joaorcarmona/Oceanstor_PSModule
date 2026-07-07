# Remote Replication Consistency Groups

## Scope

Grouping remote replication pairs so multi-LUN applications sync, split, and
switch over as one write-consistent unit. REST resource: `CONSISTENTGROUP`.

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `Get-DMReplicationConsistencyGroup` | `GET CONSISTENTGROUP` / `GET CONSISTENTGROUP/${id}` | Read-only |
| `New-DMReplicationConsistencyGroup` | `POST CONSISTENTGROUP` | Mutating |
| `Set-DMReplicationConsistencyGroup` | `PUT CONSISTENTGROUP/${id}` | Mutating |
| `Remove-DMReplicationConsistencyGroup` | `DELETE CONSISTENTGROUP/${id}` | Mutating |
| `Add-DMReplicationPairToConsistencyGroup` | `PUT ADD_MIRROR` | Mutating |
| `Remove-DMReplicationPairFromConsistencyGroup` | `PUT DEL_MIRROR` | Mutating |
| `Sync-DMReplicationConsistencyGroup` | `PUT SYNCHRONIZE_CONSISTENCY_GROUP` | Mutating (starts replication) |
| `Split-DMReplicationConsistencyGroup` | `PUT SPLIT_CONSISTENCY_GROUP` | Mutating (stops replication) |
| `Switch-DMReplicationConsistencyGroup` | `PUT SWITCH_GROUP_ROLE` | **Failover-class: swaps group roles** |

Group cmdlets accept `-Id` or `-Name`; the association cmdlets take
`-GroupId`/`-GroupName` plus `-PairId`. `New-DMReplicationConsistencyGroup`
accepts `-Name`, `-Description`, `-SynchronizationType`, `-ReplicationMode`,
`-RecoveryPolicy`, `-Speed`, `-RemoteDeviceId`,
`-LocalProtectionGroupId`/`-RemoteProtectionGroupId`, timing values, and
`-ApiProperties`.

## Common Workflows

```text
New-DMReplicationConsistencyGroup            # create empty group
Add-DMReplicationPairToConsistencyGroup      # add pairs (usually split state)
Sync-DMReplicationConsistencyGroup           # sync all members consistently
Split-DMReplicationConsistencyGroup          # pause all members
Remove-DMReplicationPairFromConsistencyGroup # detach a pair
Remove-DMReplicationConsistencyGroup         # delete the group
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

$group = New-DMReplicationConsistencyGroup -Name 'app-dr-group' -ReplicationMode Async
Add-DMReplicationPairToConsistencyGroup -GroupName 'app-dr-group' -PairId $pair.Id
Sync-DMReplicationConsistencyGroup -Name 'app-dr-group'
```

## Safety Notes

- `Switch-DMReplicationConsistencyGroup` swaps primary/secondary for every
  member pair at once — a whole-application failover. The integration harness
  gates it behind `Replication.AllowFailover`.
- Adding or removing a pair changes how that pair is controlled (group
  operations override per-pair operations while it is a member).

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-group-lifecycle.Tests.ps1`
  covers create fields, modification, `ADD_MIRROR`/`DEL_MIRROR` payloads,
  sync/split/switch endpoints, and deletion.
- Live: the opt-in Replication workflow creates a test-owned group, associates
  the test-owned pair, reads back, disassociates, and deletes. Group
  switchover is `SkippedUnsafe` unless `Replication.AllowFailover` is set.

## Known Gaps

- Batch member endpoints (`ADD_MIRROR/batch`, `DEL_MIRROR/batch`) are not
  wrapped.
- `CONSISTENTGROUP/transfer` (replication mode change) is not exposed as a
  dedicated cmdlet.

## Related Files

- `POSH-Oceanstor/Public/*ReplicationConsistencyGroup*.ps1`
- `POSH-Oceanstor/Public/Add-DMReplicationPairToConsistencyGroup.ps1`
- `POSH-Oceanstor/Public/Remove-DMReplicationPairFromConsistencyGroup.ps1`
- `POSH-Oceanstor/Private/class-OceanstorReplicationConsistencyGroup.ps1`
- `POSH-Oceanstor/Format/OceanstorReplicationConsistencyGroup.format.ps1xml`
