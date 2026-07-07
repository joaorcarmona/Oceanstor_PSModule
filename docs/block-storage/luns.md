# LUNs

## Scope

LUN lifecycle, lookup, grouping, performance reads, and LUN snapshot entry
points. Snapshot-specific operations are documented in `docs/snapshots/`.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMlun` | List LUNs or query by ID, name, WWN, filter, or LUN group | Read | Safe inventory |
| `Get-DMLunbyFilter`, `Get-DMlunByName`, `Get-DMlunByWWN`, `Get-DMlunbyLunGroup` | Legacy lookup wrappers | Read | Safe inventory |
| `New-DMLun` | Create a LUN in a storage pool | Mutate | Test-owned or planned provisioning only |
| `Set-DMLun`, `Rename-DMLun` | Modify description/name or expand capacity | Mutate | Can affect production storage |
| `Remove-DMLun` | Delete a LUN | Mutate | Data-loss risk |
| `Get-DMLunPerformance` | Realtime LUN performance wrapper | Read | Safe when performance collection is expected |

## Common Workflows

1. Select a pool with `Get-DMstoragePool`.
2. Create a LUN with `New-DMLun`.
3. Inspect with `Get-DMlun`.
4. Add to a LUN group or mapping workflow.
5. Expand with `Set-DMLun -Capacity` when planned.
6. Remove only after mappings and dependencies are gone.

## Examples

```powershell
Get-DMlun -WebSession $storage
Get-DMlun -WebSession $storage -Name 'data_lun_01'
Get-DMlun -WebSession $storage -WWN 'naa.example'

New-DMLun -WebSession $storage -LunName 'test_lun_01' -StoragePoolID '0' `
    -capacity 1024 -allocType Thin -WhatIf

Set-DMLun -WebSession $storage -LunName 'test_lun_01' -Capacity 2048 -WhatIf
Remove-DMLun -WebSession $storage -LunName 'test_lun_01' -WhatIf
```

## Safety Notes

`Remove-DMLun` can delete data and reports an error when the LUN is mapped.
Never use broad name matching for cleanup. Expansion is safer than deletion
but still changes a production object.

## Integrity Test Coverage

Read-only integrity validates `Get-DMlun` list mode and by-WWN/by-name/by-filter
lookups when sample LUNs exist. Mutating integrity has a test-owned LUN
workflow gated by `-RunMutatingTests`, `AllowMutatingTests`, and `Lun.Enabled`.
Unit tests cover creation, update, deletion, lookup wrappers, performance, and
pipeline behavior.

## Known Gaps

- No shrink workflow is documented; LUN reduction is intentionally rejected by
  unit-covered `Set-DMLun` behavior.
- Live tests require an existing placement pool ID in config.

## Related Files

- `POSH-Oceanstor/Public/Get-DMlun.ps1`
- `POSH-Oceanstor/Public/New-DMLun.ps1`
- `POSH-Oceanstor/Public/Set-DMLun.ps1`
- `POSH-Oceanstor/Public/Remove-DMLun.ps1`
- `Tests/Integration/Private/Workflows/Lun.ps1`
