# File-System HyperMetro Domains

## Scope

Active-active NAS HyperMetro at the vStore/file-system domain level: create,
start, join, split, role switch, and delete file-system HyperMetro domains.
REST resources: `FsHyperMetroDomain`, `StartFsHyperMetroDomain`,
`JoinFsHyperMetroDomain`, `SplitFsHyperMetroDomain`, and
`SwapRoleFsHyperMetroDomain`.

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `Get-DMFileHyperMetroDomain` | `GET FsHyperMetroDomain` | Read-only |
| `New-DMFileHyperMetroDomain` | `POST FsHyperMetroDomain` | Mutating |
| `Remove-DMFileHyperMetroDomain` | `DELETE FsHyperMetroDomain/${id}` | Mutating |
| `Start-DMFileHyperMetroDomain` | `POST StartFsHyperMetroDomain` | Mutating (starts NAS mirroring) |
| `Join-DMFileHyperMetroDomain` | `POST JoinFsHyperMetroDomain` | Mutating |
| `Split-DMFileHyperMetroDomain` | `POST SplitFsHyperMetroDomain` | Mutating (stops NAS mirroring) |
| `Switch-DMFileHyperMetroDomain` | `POST SwapRoleFsHyperMetroDomain` | **Failover-class: swaps domain roles** |

`New-DMFileHyperMetroDomain` accepts `-Name`, `-Description`,
`-RemoteDevices`, `-WorkMode` (`ActiveActive`, `ActivePassive`),
`-SynchronizeNetwork`, `-SynchronizeShareAuthentication`, and
`-ApiProperties`. Lifecycle cmdlets take `-Id` or `-Name`.
`Split-DMFileHyperMetroDomain` accepts `-StopRole` (`Preferred`,
`NonPreferred`); `Remove-DMFileHyperMetroDomain` accepts `-LocalDelete` and
`-ForceDelete`.

## Common Workflows

```text
Get-DMFileHyperMetroDomain     # inspect existing NAS metro domains
New-DMFileHyperMetroDomain     # create (initial setup)
Start-DMFileHyperMetroDomain   # begin mirroring
Split-DMFileHyperMetroDomain   # planned stop, choosing which role halts
Join-DMFileHyperMetroDomain    # rejoin after a split
Switch-DMFileHyperMetroDomain  # role swap (see safety)
Remove-DMFileHyperMetroDomain  # tear down
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

# Read-only inventory
Get-DMFileHyperMetroDomain

# Preview a planned split stopping the non-preferred site
Split-DMFileHyperMetroDomain -Name 'nas-metro-01' -StopRole NonPreferred -WhatIf
```

## Safety Notes

- These operations change NAS data-serving behavior for every file system in
  the domain — the highest service-impact family in the module. Split, start,
  join, and switch can interrupt or relocate client access to shares.
- No integration workflow exercises this family; all mutations are manual,
  change-controlled operations.
- Never split, switch, or remove a pre-existing domain during validation.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-nas-vstore.Tests.ps1` covers
  the collection query, create body (including `workMode` mapping), all four
  lifecycle POST endpoints, and delete flags.
- Live: `Get-DMFileHyperMetroDomain` validated read-only against a lab array
  (empty result handled correctly). No mutation coverage.

## Known Gaps

- No gated integration workflow (needs a dual-array NAS metro lab).
- No `Set-` modification cmdlet; use `-ApiProperties` on create or
  DeviceManager for post-create changes.

## Related Files

- `POSH-Oceanstor/Public/*DMFileHyperMetroDomain*.ps1`
- `POSH-Oceanstor/Private/class-OceanstorFileHyperMetroDomain.ps1`
