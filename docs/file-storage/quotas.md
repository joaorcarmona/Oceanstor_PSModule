# Quotas

## Scope

Directory, user, and user-group quota inventory and lifecycle for file systems
or dTrees.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMQuota` | List quotas by file system, dTree, type, or ID | Read | Safe inventory |
| `New-DMQuota` | Create directory, user, or user-group quota | Mutate | Capacity enforcement change |
| `Set-DMQuota` | Modify space or file limits | Mutate | Can block writes |
| `Remove-DMQuota` | Remove a quota | Mutate | Capacity policy change |

## Common Workflows

1. Identify the file system or dTree.
2. Create a directory quota with at least one hard or soft limit.
3. Read back the quota by ID.
4. Modify limits carefully.
5. Remove only test-owned quotas.

## Examples

```powershell
Get-DMQuota -WebSession $storage -FileSystemName 'test_fs_01'

New-DMQuota -WebSession $storage -FileSystemName 'test_fs_01' `
    -DtreeName 'project_a' -SpaceHardLimit 10GB -WhatIf

Set-DMQuota -WebSession $storage -Id '123' -SpaceHardLimit 20GB -WhatIf
```

## Safety Notes

Quota changes can prevent client writes or alter enforcement. Confirm units
and quota target before applying changes.

## Integrity Test Coverage

Read-only integrity includes quota reads when the NAS workflow produces sample
objects. Mutating integrity validates quota lifecycle when `Nas.EnableQuota`
and `Nas.EnableDTree` are true.

## Known Gaps

- Live coverage currently focuses on a test-owned dTree quota.
- Broader matrix coverage for user and user-group quotas is not documented as
  validated.

## Related Files

- `POSH-Oceanstor/Public/Get-DMQuota.ps1`
- `POSH-Oceanstor/Public/New-DMQuota.ps1`
- `POSH-Oceanstor/Public/Set-DMQuota.ps1`
- `POSH-Oceanstor/Public/Remove-DMQuota.ps1`
- `Tests/Unit/Public/Quota-actions.Tests.ps1`
