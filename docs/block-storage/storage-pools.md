# Storage Pools

## Scope

Storage pool inventory and disk lookup. The module does not implement storage
pool creation, update, or deletion.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMstoragePool` | List pools or filter by name | Read | Safe inventory |
| `Get-DMDiskByStoragePool` | Legacy wrapper to list disks by pool object, name, or ID | Read | Safe inventory |
| `Get-DMStoragePoolPerformance` | Realtime pool performance wrapper | Read | Safe when performance collection is expected |

## Common Workflows

1. List pools before selecting placement for a LUN or file system.
2. Confirm pool disks when troubleshooting capacity or backend health.
3. Use performance wrappers for realtime triage, not provisioning.

## Examples

```powershell
Get-DMstoragePool -WebSession $storage
Get-DMstoragePool -WebSession $storage -Name 'Pool_01'
Get-DMstoragePool -WebSession $storage -Name 'Pool_01' | Get-DMDiskByStoragePool
```

## Safety Notes

These cmdlets are read-only. Passing a pool ID to `New-DMLun` or
`New-DMFileSystem` is a separate mutating action and should be reviewed.

## Integrity Test Coverage

Read-only integrity validates `Get-DMstoragePool` and disk lookup by pool when
sample data is available. Unit tests cover `Get-DMDiskByStoragePool` and
`Get-DMStoragePoolPerformance`.

## Known Gaps

- No storage pool create/update/delete cmdlets are implemented.
- Capacity planning examples are intentionally limited to inventory and
  performance reads.

## Related Files

- `POSH-Oceanstor/Public/Get-DMstoragePool.ps1`
- `POSH-Oceanstor/Public/Get-DMDiskByStoragePool.ps1`
- `POSH-Oceanstor/Public/Get-DMStoragePoolPerformance.ps1`
- `Tests/Unit/Public/Get-DMDiskByStoragePool.Tests.ps1`
