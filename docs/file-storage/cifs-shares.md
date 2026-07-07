# CIFS Shares

## Scope

CIFS share inventory, creation, limited update, and removal.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMShare -ShareType CIFS` | List CIFS shares | Read | Safe inventory |
| `New-DMCifsShare` | Create a CIFS share | Mutate | Can expose NAS namespace |
| `Set-DMCifsShare` | Update description and access-based enumeration setting | Mutate | Can affect clients |
| `Remove-DMCifsShare` | Remove a CIFS share | Mutate | Access disruption risk |

## Common Workflows

1. Confirm CIFS service prerequisites outside this module.
2. Create a file system.
3. Create a CIFS share.
4. Update only supported properties.
5. Remove the share before deleting the file system.

## Examples

```powershell
Get-DMShare -WebSession $storage -ShareType CIFS

New-DMCifsShare -WebSession $storage -ShareName 'test_cifs' `
    -FileSystemName 'test_fs_01' -WhatIf

Set-DMCifsShare -WebSession $storage -ShareName 'test_cifs' `
    -Description 'validation share' -WhatIf
```

## Safety Notes

CIFS shares depend on external service identity and client access planning.
This module documents share objects, not AD/domain service setup.

## Integrity Test Coverage

Read-only integrity validates `Get-DMShare:CIFS`. Mutating integrity validates
CIFS share lifecycle when `Nas.Enabled` and `Nas.EnableCifs` are true. Unit
tests cover `New-DMCifsShare`.

## Known Gaps

- AD, LDAP, DNS-for-CIFS, and CIFS service configuration cmdlets are not
  implemented in this domain.
- CIFS permission/ACL management is not documented as implemented.

## Related Files

- `POSH-Oceanstor/Public/New-DMCifsShare.ps1`
- `POSH-Oceanstor/Public/Set-DMCifsShare.ps1`
- `POSH-Oceanstor/Public/Remove-DMCifsShare.ps1`
- `Tests/Unit/Public/Remove-storage-and-new-cifs.Tests.ps1`
