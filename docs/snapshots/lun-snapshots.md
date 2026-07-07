# LUN Snapshots

## Scope

LUN snapshot inventory, creation, activation, restart, resize, restore, copy,
and removal.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMLunSnapshot` | List or query LUN snapshots | Read | Safe inventory |
| `New-DMLunSnapshot` | Create a LUN snapshot | Mutate | Creates recovery point |
| `Enable-DMLunSnapshot` | Activate snapshot | Mutate | State change |
| `Restart-DMLunSnapshot` | Reactivate/restart snapshot | Mutate | State change |
| `Resize-DMLunSnapshot` | Expand snapshot capacity | Mutate | Capacity impact |
| `Restore-DMLunSnapshot` | Roll back from snapshot | Mutate | Data overwrite risk |
| `New-DMLunSnapshotCopy` | Create a snapshot copy | Mutate | Capacity/recovery-point impact |
| `Remove-DMLunSnapShot` | Delete a snapshot | Mutate | Removes recovery point |

## Common Workflows

1. Create a snapshot for a test-owned LUN.
2. Enable or restart it only when required.
3. Create a copy for isolated validation.
4. Restore only against a test-owned LUN.
5. Remove snapshots by captured ID/name during cleanup.

## Examples

```powershell
Get-DMLunSnapshot -WebSession $storage
Get-DMLunSnapshot -WebSession $storage -LunName 'test_lun_01'

New-DMLunSnapshot -WebSession $storage -SnapshotName 'test_snap_01' `
    -SourceLunName 'test_lun_01' -WhatIf

Restore-DMLunSnapshot -WebSession $storage -SnapShotName 'test_snap_01' `
    -RollbackSpeed Medium -WhatIf
```

## Safety Notes

Restore can overwrite the source LUN. Removal deletes a recovery point. Keep
snapshot tests isolated to test-owned LUNs.

## Integrity Test Coverage

Read-only integrity validates `Get-DMLunSnapshot`. Mutating integrity covers
LUN snapshot creation/actions under the test-owned LUN workflow. Unit tests
cover creation, removal, copy, and action cmdlets.

## Known Gaps

- Production rollback runbooks are intentionally not included.
- Restore examples remain guarded with `-WhatIf`.

## Related Files

- `POSH-Oceanstor/Public/*LunSnapshot*.ps1`
- `POSH-Oceanstor/Public/Remove-DMLunSnapShot.ps1`
- `Tests/Unit/Public/New-DMLunSnapshot.Tests.ps1`
- `Tests/Unit/Public/snapshot-actions.Tests.ps1`
