# dTrees

## Scope

dTree creation, update, rename, and removal under a file system.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `New-DMdTree` | Create a dTree under a file system | Mutate | Namespace and quota structure change |
| `Set-DMdTree` | Rename or modify dTree settings | Mutate | Can affect access and quotas |
| `Remove-DMDTree` | Delete a dTree | Mutate | Data-loss or namespace risk |

## Common Workflows

1. Create a file system.
2. Create a dTree for a project or quota boundary.
3. Optionally create dTree-scoped shares and quotas.
4. Remove dependent quotas and shares before deleting the dTree.

## Examples

```powershell
New-DMdTree -WebSession $storage -dTreeName 'project_a' `
    -fileSystemName 'test_fs_01' -WhatIf

Set-DMdTree -WebSession $storage -FileSystemName 'test_fs_01' `
    -DTreeName 'project_a' -NewName 'project_a_renamed' -WhatIf
```

## Safety Notes

dTree operations can affect namespace layout and quota ownership. Do not
remove dTrees that were not created by the current run.

## Integrity Test Coverage

Mutating integrity validates dTree lifecycle when `Nas.EnableDTree` is true.
Unit tests cover creation, update translation, and removal.

## Known Gaps

- There is no dedicated public `Get-DMdTree` cmdlet in the current surface;
  dTree lookup is performed internally by operations that need it.

## Related Files

- `POSH-Oceanstor/Public/New-DMdTree.ps1`
- `POSH-Oceanstor/Public/Set-DMdTree.ps1`
- `POSH-Oceanstor/Public/Remove-DMDTree.ps1`
- `Tests/Unit/Public/Remove-storage-and-new-cifs.Tests.ps1`
