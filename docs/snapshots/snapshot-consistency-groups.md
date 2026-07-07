# Snapshot Consistency Groups

## Scope

Snapshot consistency-group inventory, creation from protection groups, copy,
restart, restore, and removal.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMSnapshotConsistencyGroup` | List consistency groups | Read | Safe inventory |
| `New-DMSnapshotConsistencyGroup` | Create group from a protection group | Mutate | Creates recovery point group |
| `New-DMSnapshotConsistencyGroupCopy` | Create a copy of a group | Mutate | Capacity/recovery-point impact |
| `Enable-DMSnapshotConsistencyGroup` | Activate group | Mutate | State change |
| `Restart-DMSnapshotConsistencyGroup` | Restart group | Mutate | State change |
| `Restore-DMSnapshotConsistencyGroup` | Restore group | Mutate | Data overwrite risk |
| `Remove-DMSnapshotConsistencyGroup` | Delete group | Mutate | Removes recovery point |

## Common Workflows

1. Create a protection group for test-owned LUNs.
2. Create a snapshot consistency group.
3. Copy or restart only when required.
4. Restore only against test-owned targets.
5. Remove copies and groups during cleanup.

## Examples

```powershell
Get-DMSnapshotConsistencyGroup -WebSession $storage

New-DMSnapshotConsistencyGroup -WebSession $storage -Name 'test_cg_snap' `
    -ProtectionGroupName 'test_protect' -WhatIf

Restore-DMSnapshotConsistencyGroup -WebSession $storage -Name 'test_cg_snap' `
    -RestoreSpeed Medium -WhatIf
```

## Safety Notes

Consistency-group restore can affect multiple LUNs. Use only test-owned
protection groups in validation.

## Integrity Test Coverage

Read-only integrity validates `Get-DMSnapshotConsistencyGroup`. Mutating
integrity covers snapshot consistency-group lifecycle under the protection
workflow when `Protection.Enabled` is true.

## Known Gaps

- Production consistency-group rollback runbooks are not included.

## Related Files

- `POSH-Oceanstor/Public/*SnapshotConsistencyGroup*.ps1`
- `Tests/Integration/Private/Workflows/Protection.ps1`
- `Tests/Unit/Public/protection-and-consistency-groups.Tests.ps1`
