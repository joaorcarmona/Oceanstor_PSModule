# Protection Groups

## Scope

Protection-group inventory, lifecycle, LUN membership, and relationship to
snapshot consistency groups.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMProtectionGroup` | List or query protection groups by ID, name, LUN, or LUN group | Read | Safe inventory |
| `New-DMProtectionGroup`, `Set-DMProtectionGroup`, `Rename-DMProtectionGroup`, `Remove-DMProtectionGroup` | Protection-group lifecycle | Mutate | Protection relationship mutation |
| `Add-DMLunToProtectionGroup`, `Remove-DMLunFromProtectionGroup` | LUN membership | Mutate | Can affect protection behavior |
| `New-DMSnapshotConsistencyGroup` | Create snapshot consistency group from a protection group | Mutate | Snapshot recovery point mutation |

## Common Workflows

1. Create or identify the LUN/LUN group to protect.
2. Create a protection group.
3. Add test-owned LUNs to the protection group.
4. Create snapshot consistency groups when required.
5. Remove membership before cleanup.

## Examples

```powershell
Get-DMProtectionGroup -WebSession $storage
Get-DMProtectionGroup -WebSession $storage -LunName 'test_lun_01'

New-DMProtectionGroup -WebSession $storage -Name 'test_protect' -WhatIf
Add-DMLunToProtectionGroup -WebSession $storage -Name 'test_protect' `
    -LunName 'test_lun_01' -WhatIf
```

## Safety Notes

Protection groups can feed snapshot and replication workflows. Do not remove
or modify existing protection groups without confirming dependent services.

## Integrity Test Coverage

Read-only integrity validates `Get-DMProtectionGroup`. Mutating integrity has
a test-owned protection workflow gated by `Protection.Enabled` and dependent
on `Lun.Enabled` and `LunGroup.Enabled`.

## Known Gaps

- Replication and HyperMetro protection details live in
  `docs/replication-hypermetro/`, not this block-storage page.
- Operational runbooks for production protection-group changes are not
  included.

## Related Files

- `POSH-Oceanstor/Public/*ProtectionGroup*.ps1`
- `Tests/Integration/Private/Workflows/Protection.ps1`
- `Tests/Unit/Public/protection-and-consistency-groups.Tests.ps1`
