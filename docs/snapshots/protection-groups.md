# Protection Groups and Snapshots

## Scope

The snapshot domain uses protection groups as a source for snapshot
consistency-group workflows.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMProtectionGroup` | Inventory protection groups | Read | Safe inventory |
| `New-DMProtectionGroup` | Create a group for protected objects | Mutate | Protection relationship mutation |
| `Add-DMLunToProtectionGroup` | Add test-owned LUNs | Mutate | Protection scope change |
| `New-DMSnapshotConsistencyGroup` | Create a snapshot consistency group from protection group | Mutate | Creates recovery point group |

## Common Workflows

1. Create test-owned LUNs and optionally a LUN group.
2. Create a protection group.
3. Add test-owned LUNs.
4. Create snapshot consistency groups from that protection group.

## Examples

```powershell
Get-DMProtectionGroup -WebSession $storage

New-DMProtectionGroup -WebSession $storage -Name 'test_protect' -WhatIf
New-DMSnapshotConsistencyGroup -WebSession $storage -Name 'test_cg_snap' `
    -ProtectionGroupName 'test_protect' -WhatIf
```

## Safety Notes

Protection groups may also participate in replication or HyperMetro workflows.
This page only covers the snapshot relationship.

## Integrity Test Coverage

The protection workflow validates protection-group and snapshot
consistency-group behavior with test-owned resources when enabled.

## Known Gaps

- Replication/HyperMetro protection behavior is documented separately in
  `docs/replication-hypermetro/`.

## Related Files

- `docs/block-storage/protection-groups.md`
- `POSH-Oceanstor/Public/*ProtectionGroup*.ps1`
- `Tests/Integration/Private/Workflows/Protection.ps1`
