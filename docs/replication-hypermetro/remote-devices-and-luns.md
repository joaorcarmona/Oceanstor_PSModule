# Remote Devices and Remote LUNs

## Scope

Read-only discovery of the remote arrays this system is linked to and the
remote LUNs that can serve as replication or HyperMetro secondaries. Both
cmdlets are prerequisites for creating pairs: they resolve the opaque remote
device and remote resource IDs that the create cmdlets need.

## Cmdlets

| Cmdlet | REST resource | Kind |
|---|---|---|
| `Get-DMRemoteDevice` | `remote_device` | Read-only |
| `Get-DMRemoteLun` | `remote_lun` | Read-only |

`Get-DMRemoteDevice` supports `-Name` (client-side wildcard) and `-Id` (exact
lookup). `Get-DMRemoteLun` filters by `-RemoteDeviceId`, `-Name`, `-Id`,
`-RemoteServiceType` (`ReplicationSecondaryLun`, `HyperMetroSecondaryLun`,
`ReplicationStandbySecondaryLun`), and `-ArrayType` (`ReplicationDevice`,
`HeterogeneousDevice`, `UnknownDevice`, `CloudReplicationDevice`).

## Common Workflows

1. List remote devices to confirm the replication link is healthy.
2. List remote LUNs for the intended service type before creating a pair.
3. Pass the resolved IDs (or names) to `New-DMReplicationPair` or
   `New-DMHyperMetroPair`.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

# All linked remote arrays
Get-DMRemoteDevice

# Remote LUNs eligible as HyperMetro secondaries on remote device 0
Get-DMRemoteLun -RemoteDeviceId '0' -RemoteServiceType HyperMetroSecondaryLun
```

## Safety Notes

Both cmdlets are pure GET wrappers and never change array state. They are safe
to run against production arrays.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-readonly.Tests.ps1` verifies
  the documented resources, exact `-Id` lookups, and returned types.
- Live: validated read-only against a lab array (remote devices and remote
  LUNs enumerate with correct types). Not yet part of the standing
  `ReadValidation.ps1` getter sweep.

## Known Gaps

- `remote_lun/scan_remote_lun` (rescan) is not wrapped.
- Name filtering happens client-side after a batch query.

## Related Files

- `POSH-Oceanstor/Public/Get-DMRemoteDevice.ps1`
- `POSH-Oceanstor/Public/Get-DMRemoteLun.ps1`
- `POSH-Oceanstor/Private/class-OceanstorRemoteDevice.ps1`
- `POSH-Oceanstor/Private/class-OceanstorRemoteLun.ps1`
