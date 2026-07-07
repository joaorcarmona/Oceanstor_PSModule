# File Systems

## Scope

File-system inventory, lifecycle, update/resize, removal, performance reads,
and snapshot entry points.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMFileSystem` | List file systems or filter by name | Read | Safe inventory |
| `New-DMFileSystem` | Create a file system in a storage pool | Mutate | Test-owned or planned provisioning |
| `Set-DMFileSystem`, `Rename-DMFileSystem` | Rename, resize, or modify properties | Mutate | Can affect production NAS |
| `Remove-DMFileSystem` | Delete a file system | Mutate | Data-loss risk |
| `Get-DMFileSystemPerformance` | Realtime NAS performance wrapper | Read | Safe when performance collection is expected |

## Common Workflows

1. Select a storage pool.
2. Create a file system.
3. Create shares and client permissions.
4. Resize or rename only during a planned change.
5. Remove only after shares, snapshots, dTrees, and quotas are handled.

## Examples

```powershell
Get-DMFileSystem -WebSession $storage
Get-DMFileSystem -WebSession $storage -Name 'fs01'

New-DMFileSystem -WebSession $storage -FileSystemName 'test_fs_01' `
    -StoragePoolID '0' -capacity 1 -WhatIf

Set-DMFileSystem -WebSession $storage -FileSystemName 'test_fs_01' `
    -Capacity 2 -WhatIf
```

## Safety Notes

File-system removal is destructive. Set/resize operations can affect quota,
snapshot, and share behavior.

## Integrity Test Coverage

Read-only integrity validates `Get-DMFileSystem`. Mutating integrity validates
test-owned file-system create, set/resize, rename, snapshot dependency, and
cleanup when `Nas.Enabled = $true`.

## Known Gaps

- NAS service prerequisites are not configured by this module.
- Production migration or client cutover runbooks are not included.

## Related Files

- `POSH-Oceanstor/Public/Get-DMFileSystem.ps1`
- `POSH-Oceanstor/Public/New-DMFileSystem.ps1`
- `POSH-Oceanstor/Public/Set-DMFileSystem.ps1`
- `Tests/Integration/Private/Workflows/Nas.ps1`
