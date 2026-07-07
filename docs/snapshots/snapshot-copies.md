# Snapshot Copies

## Scope

Snapshot copy creation for LUN snapshots and snapshot consistency groups.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `New-DMLunSnapshotCopy` | Create a copy of a LUN snapshot | Mutate | Capacity/recovery-point impact |
| `New-DMSnapshotConsistencyGroupCopy` | Create a copy of a snapshot consistency group | Mutate | Capacity/recovery-point impact |

## Common Workflows

1. Create or identify a test-owned source snapshot.
2. Create a named copy.
3. Read back the copy through normal snapshot inventory.
4. Remove copies during cleanup.

## Examples

```powershell
New-DMLunSnapshotCopy -WebSession $storage -SourceSnapShotName 'test_snap_01' `
    -SnapshotCopyName 'test_snap_copy_01' -WhatIf

New-DMSnapshotConsistencyGroupCopy -WebSession $storage -SourceName 'test_cg_snap' `
    -Name 'test_cg_snap_copy' -WhatIf
```

## Safety Notes

Copies can consume capacity and become additional recovery points requiring
cleanup. Do not create copies of production snapshots during tests.

## Integrity Test Coverage

Unit tests cover LUN snapshot copy and consistency-group copy behavior.
Mutating integrity covers copies as part of test-owned snapshot workflows
when the parent workflows are enabled.

## Known Gaps

- Split/clone semantics beyond implemented copy cmdlets are not documented as
  supported.

## Related Files

- `POSH-Oceanstor/Public/New-DMLunSnapshotCopy.ps1`
- `POSH-Oceanstor/Public/New-DMSnapshotConsistencyGroupCopy.ps1`
- `Tests/Unit/Public/New-DMLunSnapshotCopy.Tests.ps1`
