# vStore Pairs

## Scope

vStore-level DR pairing for NAS tenants: pairing a local vStore with a remote
vStore for either remote replication or HyperMetro, plus sync, split, and role
switch. REST resources: `vstore_pair` (query/create) and `VSTORE_PAIR/*`
(lifecycle).

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `Get-DMVStorePair` | `GET vstore_pair` | Read-only |
| `New-DMVStorePair` | `POST vstore_pair` | Mutating (creates tenant DR relationship) |
| `Remove-DMVStorePair` | `DELETE VSTORE_PAIR/${id}` | Mutating |
| `Sync-DMVStorePair` | `PUT VSTORE_PAIR/sync` | Mutating |
| `Split-DMVStorePair` | `PUT VSTORE_PAIR/split` | Mutating |
| `Switch-DMVStorePair` | `PUT VSTORE_PAIR/swap` | **Failover-class: swaps vStore roles** |

`Get-DMVStorePair` filters by `-ReplicationType` (`HyperMetro`,
`RemoteReplication`) and `-Id`. `New-DMVStorePair` requires `-LocalVStoreId`,
`-RemoteVStoreId`, and `-ReplicationType`; `-RemoteDeviceId` is required for
`RemoteReplication` and `-DomainId` for `HyperMetro`. Optional:
`-PreferredMode` (`ConsistentWithActive`, `Manual`), `-PreferredSite`
(`Local`, `Remote`), `-SynchronizeNetwork`,
`-SynchronizeShareAuthentication`, `-ApiProperties`. `Remove-DMVStorePair`
accepts `-Id` or `-LocalVStoreName`/`-RemoteVStoreName` plus `-LocalDelete`.
`Sync`/`Split`/`Switch` take `-Id` (pipeline by property name).

## Common Workflows

```text
Get-DMvStore                 # resolve local vStore IDs (existing cmdlet)
New-DMVStorePair             # pair local and remote vStores
Sync-DMVStorePair            # synchronize configuration/data
Split-DMVStorePair           # pause
Switch-DMVStorePair          # role swap (see safety)
Remove-DMVStorePair          # tear down
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

# Read-only inventory, optionally by type
Get-DMVStorePair
Get-DMVStorePair -ReplicationType HyperMetro
```

## Safety Notes

- vStore pairs carry tenant-level service state (networks, shares,
  authentication). Sync/split/switch can affect NAS client access for every
  file system in the tenant — broader blast radius than a single LUN pair.
- `Switch-DMVStorePair` is a tenant failover. No integration workflow
  exercises vStore mutation; treat all vStore mutations as manual,
  change-controlled operations.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-nas-vstore.Tests.ps1` covers
  the documented filter, create body (`REPTYPE`, `PREFERREDMODE`), lifecycle
  endpoints (`sync`, `split`, `swap`), and the local-delete flag.
- Live: `Get-DMVStorePair` validated read-only against a lab array (empty
  result handled correctly). No gated mutation workflow exists for vStore
  pairs yet.

## Known Gaps

- No integration workflow for vStore pair lifecycle (needs a lab with a
  disposable test vStore on both arrays).
- No `Set-DMVStorePair` modification cmdlet.

## Related Files

- `POSH-Oceanstor/Public/*DMVStorePair*.ps1`
- `POSH-Oceanstor/Private/class-OceanstorVStorePair.ps1`
