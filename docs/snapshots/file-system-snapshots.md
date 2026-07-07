# File-System Snapshots

## Scope

File-system snapshot inventory, creation, deletion, and restore.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMFileSystemSnapshot` | List snapshots for a file system or query by name | Read | Safe inventory |
| `New-DMFileSystemSnapshot` | Create a file-system snapshot | Mutate | Creates recovery point |
| `Restore-DMFileSystemSnapshot` | Restore a file-system snapshot | Mutate | Data overwrite risk |
| `Remove-DMFileSystemSnapshot` | Delete snapshot | Mutate | Removes recovery point |

## Common Workflows

1. Create a test-owned file system.
2. Create a file-system snapshot.
3. Read it back by file system and name.
4. Restore only in isolated validation.
5. Delete by captured name during cleanup.

## Examples

```powershell
Get-DMFileSystemSnapshot -WebSession $storage -FileSystemName 'test_fs_01'

New-DMFileSystemSnapshot -WebSession $storage -FileSystemName 'test_fs_01' `
    -SnapshotName 'test_fs_snap_01' -WhatIf

Restore-DMFileSystemSnapshot -WebSession $storage -FileSystemName 'test_fs_01' `
    -SnapshotName 'test_fs_snap_01' -WhatIf
```

## Safety Notes

Restore can roll file-system data back. Delete only snapshots you own.

## Integrity Test Coverage

Read-only integrity validates `Get-DMFileSystemSnapshot` when a file system is
available. Mutating integrity covers file-system snapshots when
`Nas.EnableFileSystemSnapshot` is true.

## Known Gaps

- No snapshot schedule support for file systems was confirmed outside HyperCDP
  block scheduling.

## Related Files

- `POSH-Oceanstor/Public/*FileSystemSnapshot*.ps1`
- `Tests/Unit/Public/filesystem-snapshots.Tests.ps1`
- `Tests/Integration/Private/Workflows/Nas.ps1`
