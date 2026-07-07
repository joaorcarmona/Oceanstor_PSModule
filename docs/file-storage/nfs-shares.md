# NFS Shares

## Scope

NFS share inventory, creation, update, and removal.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMShare -ShareType NFS` | List NFS shares | Read | Safe inventory |
| `New-DMnfsShare` | Create an NFS share for a file system or dTree | Mutate | Can expose NAS namespace |
| `Set-DMnfsShare` | Modify NFS share properties | Mutate | Can affect clients |
| `Remove-DMNfsShare` | Remove an NFS share | Mutate | Access disruption risk |

## Common Workflows

1. Create or select a file system.
2. Create an NFS share path.
3. Add NFS client permissions.
4. Remove clients before removing the share.

## Examples

```powershell
Get-DMShare -WebSession $storage -ShareType NFS

New-DMnfsShare -WebSession $storage -sharepath '/test_fs_01/' `
    -FileSystemId '123' -WhatIf

Set-DMnfsShare -WebSession $storage -SharePath '/test_fs_01/' `
    -Description 'validation share' -WhatIf
```

## Safety Notes

Share creation can expose a path once clients are granted. Share removal can
break active clients.

## Integrity Test Coverage

Read-only integrity validates `Get-DMShare:NFS`. Mutating integrity validates
NFS share lifecycle when `Nas.Enabled` and `Nas.EnableNfs` are true.

## Known Gaps

- Service-level NFS configuration is not implemented.
- Host-side mount validation is outside the module tests.

## Related Files

- `POSH-Oceanstor/Public/New-DMnfsShare.ps1`
- `POSH-Oceanstor/Public/Set-DMnfsShare.ps1`
- `POSH-Oceanstor/Public/Remove-DMNfsShare.ps1`
- `Tests/Integration/Private/Workflows/Nas.ps1`
