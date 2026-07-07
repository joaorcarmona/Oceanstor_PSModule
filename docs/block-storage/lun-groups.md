# LUN Groups

## Scope

LUN-group lifecycle and membership. LUN groups are commonly used with mapping
views and QoS associations.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMlunGroup` | List or query LUN groups | Read | Safe inventory |
| `New-DMLunGroup`, `Set-DMLunGroup`, `Rename-DMLunGroup`, `Remove-DMLunGroup` | LUN-group lifecycle | Mutate | Test-owned or planned only |
| `Add-DMLunToLunGroup`, `Remove-DMLunFromLunGroup` | Membership changes | Mutate | Can affect mapped access |
| `Get-DMlunbyLunGroup` | List LUNs in a group | Read | Safe inventory |

## Common Workflows

1. Create a LUN group for related application LUNs.
2. Add LUNs to the group.
3. Attach the LUN group to a mapping view or direct host mapping.
4. Remove membership before deleting the group.

## Examples

```powershell
Get-DMlunGroup -WebSession $storage
Get-DMlun -WebSession $storage -LunGroupName 'app_luns'

New-DMLunGroup -WebSession $storage -Name 'test_luns' -ApplicationType Other -WhatIf
Add-DMLunToLunGroup -WebSession $storage -LunName 'test_lun_01' `
    -LunGroupName 'test_luns' -WhatIf
```

## Safety Notes

Changing LUN-group membership can change the LUNs visible through mappings.
Use exact names or captured IDs and avoid broad cleanup.

## Integrity Test Coverage

Read-only integrity validates LUN-group inventory and LUN-by-group lookups.
Mutating integrity has a test-owned LUN-group workflow gated by
`LunGroup.Enabled` and generally depends on the test-owned LUN workflow.
Optional pipeline batch coverage is gated by `RunPipelineBatchCoverage` or
`LunGroup.EnablePipelineBatchCoverage`.

## Known Gaps

- Large-scale grouping and host LUN ID planning examples are not included.

## Related Files

- `POSH-Oceanstor/Public/Get-DMlunGroup.ps1`
- `POSH-Oceanstor/Public/New-DMLunGroup.ps1`
- `POSH-Oceanstor/Public/Add-DMLunToLunGroup.ps1`
- `Tests/Integration/Private/Workflows/LunGroup.ps1`
