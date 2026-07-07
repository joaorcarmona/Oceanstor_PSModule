# HyperMetro Consistency Groups

## Scope

Grouping HyperMetro pairs so multi-LUN applications are mirrored, suspended,
started, and switched as one consistent unit. REST resource:
`HyperMetro_ConsistentGroup`; pair association uses
`hyperMetro/associate/pair`.

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `Get-DMHyperMetroConsistencyGroup` | `GET HyperMetro_ConsistentGroup` / `.../${id}` | Read-only |
| `New-DMHyperMetroConsistencyGroup` | `POST HyperMetro_ConsistentGroup` | Mutating |
| `Set-DMHyperMetroConsistencyGroup` | `PUT HyperMetro_ConsistentGroup/${id}` | Mutating |
| `Remove-DMHyperMetroConsistencyGroup` | `DELETE HyperMetro_ConsistentGroup/${id}` | Mutating |
| `Add-DMHyperMetroPairToConsistencyGroup` | `POST hyperMetro/associate/pair` | Mutating |
| `Remove-DMHyperMetroPairFromConsistencyGroup` | `DELETE hyperMetro/associate/pair` | Mutating |
| `Sync-DMHyperMetroConsistencyGroup` | `PUT HyperMetro_ConsistentGroup/sync` | Mutating (starts mirroring) |
| `Suspend-DMHyperMetroConsistencyGroup` | `PUT HyperMetro_ConsistentGroup/stop` | Mutating (pauses mirroring) |
| `Start-DMHyperMetroConsistencyGroup` | `PUT HyperMetro_ConsistentGroup/start` | **Force start: overrides arbitration** |
| `Switch-DMHyperMetroConsistencyGroup` | `PUT HyperMetro_ConsistentGroup/switch` | **Priority-class: swaps preferred site** |

`New-DMHyperMetroConsistencyGroup` accepts `-Name`, `-DomainId`/`-DomainName`,
`-Description`, `-RecoveryPolicy`, `-Speed`, `-IsolationThresholdTime`,
`-LocalProtectionGroupId`/`-RemoteProtectionGroupId`, `-RemoteVStoreId`, and
`-ApiProperties`. Association cmdlets take `-GroupId`/`-GroupName` plus
`-PairId`.

## Common Workflows

```text
New-DMHyperMetroConsistencyGroup            # create in a domain
Add-DMHyperMetroPairToConsistencyGroup      # add pairs (suspend them first)
Sync-DMHyperMetroConsistencyGroup           # mirror all members
Suspend-DMHyperMetroConsistencyGroup        # pause all members
Remove-DMHyperMetroPairFromConsistencyGroup # detach a pair
Remove-DMHyperMetroConsistencyGroup         # delete the group
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

$group = New-DMHyperMetroConsistencyGroup -Name 'app-metro-group' -DomainName 'metro-domain-01'
Add-DMHyperMetroPairToConsistencyGroup -GroupName 'app-metro-group' -PairId $pair.Id
Sync-DMHyperMetroConsistencyGroup -Name 'app-metro-group'
```

## Safety Notes

- `Start-DMHyperMetroConsistencyGroup` force-starts every member pair without
  arbitration — the group-wide version of the most dangerous pair operation.
- `Switch-DMHyperMetroConsistencyGroup` changes the preferred site for the
  whole application. The integration harness gates it behind
  `HyperMetro.AllowPrioritySwitch`.
- Group operations override member-pair operations while pairs are members.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-group-lifecycle.Tests.ps1`
  covers create with resolved domain names, modification, association
  payloads, sync/stop/start/switch endpoints, and deletion.
- Live: the opt-in HyperMetro workflow creates a test-owned group, associates
  the test-owned pair, exercises safe lifecycle operations, and cleans up by
  captured ID. Group switch is `SkippedUnsafe` unless
  `HyperMetro.AllowPrioritySwitch` is set.

## Known Gaps

- Batch association endpoints (`hyperMetro/associate/pair/batch`) are not
  wrapped.
- The group preferred-policy endpoint
  (`HyperMetro_ConsistentGroup/modifyPreferredPolicy`) is reachable only via
  `-ApiProperties`.

## Related Files

- `POSH-Oceanstor/Public/*DMHyperMetroConsistencyGroup*.ps1`
- `POSH-Oceanstor/Public/Add-DMHyperMetroPairToConsistencyGroup.ps1`
- `POSH-Oceanstor/Public/Remove-DMHyperMetroPairFromConsistencyGroup.ps1`
- `POSH-Oceanstor/Private/class-OceanstorHyperMetroConsistencyGroup.ps1`
- `POSH-Oceanstor/Format/OceanstorHyperMetroConsistencyGroup.format.ps1xml`
