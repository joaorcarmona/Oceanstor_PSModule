# NFS Clients

## Scope

NFS share authorization clients and permission updates.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMnfsFileClient` | List NFS clients | Read | Safe inventory |
| `New-DMnfsClient` | Add client permission to an NFS share | Mutate | Grants access |
| `Set-DMnfsClient` | Modify access, squash, anonymous ID, or root-squash behavior | Mutate | Can grant or remove access |
| `Remove-DMNfsClient` | Remove client permission | Mutate | Access disruption risk |

## Common Workflows

1. Create or identify an NFS share.
2. Add a client with least-privilege access.
3. Modify access only after confirming client impact.
4. Remove client permissions before share cleanup.

## Examples

```powershell
Get-DMnfsFileClient -WebSession $storage

New-DMnfsClient -WebSession $storage -clientName '192.0.2.50' `
    -shareId '123' -Permission 'read-only' -WhatIf

Set-DMnfsClient -WebSession $storage -ClientName '192.0.2.50' `
    -Access 'read-write' -WhatIf
```

## Safety Notes

NFS client changes are access-control changes. Use documentation IPs such as
`192.0.2.50` in examples and never publish lab addresses.

## Integrity Test Coverage

Read-only integrity validates `Get-DMnfsFileClient`. Mutating integrity uses
`Nas.NfsClientName` and validates client lifecycle when `Nas.EnableNfs` is
true.

## Known Gaps

- Complex netgroup, DNS, and export-policy runbooks are not included.

## Related Files

- `POSH-Oceanstor/Public/Get-DMnfsFileClient.ps1`
- `POSH-Oceanstor/Public/New-DMnfsClient.ps1`
- `POSH-Oceanstor/Public/Set-DMnfsClient.ps1`
- `POSH-Oceanstor/Public/Remove-DMNfsClient.ps1`
