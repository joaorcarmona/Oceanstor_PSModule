# Mapping Views

## Scope

Mapping-view inventory and mutation, including host group, LUN group, and port
group membership, plus direct LUN/LUN-group to host/host-group mapping helpers.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMMappingView` | List mapping views or filter by member names | Read | Safe inventory |
| `New-DMMappingView`, `Remove-DMMappingView` | Mapping-view lifecycle | Mutate | Access-path mutation |
| `Set-DMMappingView` | Modify a mapping view's name/description (labels only) | Mutate | High-impact confirm; associations untouched |
| `Rename-DMMappingView` | Rename a mapping view (delegates to `Set-DMMappingView`) | Mutate | High-impact confirm |
| `Add-DMHostGroupToMappingView`, `Remove-DMHostGroupFromMappingView` | Host-group membership | Mutate | Access-path mutation |
| `Add-DMLunGroupToMappingView`, `Remove-DMLunGroupFromMappingView` | LUN-group membership | Mutate | Access-path mutation |
| `Add-DMPortGroupToMappingView`, `Remove-DMPortGroupFromMappingView` | Port-group membership | Mutate | Access-path mutation |
| `Add-DMmapLunToHost`, `Remove-DMmapLunFromHost` | Direct LUN to host map/unmap | Mutate | Access-path mutation |
| `Add-DMmapLunGroupToHost`, `Remove-DMunmapLunGroupFromHost` | Direct LUN group to host map/unmap | Mutate | Access-path mutation |
| `Add-DMmapLunGroupToHostGroup`, `Remove-DMunmapLunGroupFromHostGroup` | Direct LUN group to host group map/unmap | Mutate | Access-path mutation |

## Common Workflows

1. Create host and LUN groups.
2. Create a mapping view.
3. Add host group, LUN group, and port group to the view.
4. Verify host access from the array and host side.
5. Remove memberships before deleting the view.

## Examples

```powershell
Get-DMMappingView -WebSession $storage
Get-DMMappingView -WebSession $storage -HostGroupName 'app_hosts'

New-DMMappingView -WebSession $storage -Name 'test_map' -WhatIf
Add-DMLunGroupToMappingView -WebSession $storage -LunGroupName 'test_luns' `
    -MappingViewName 'test_map' -WhatIf
Add-DMHostGroupToMappingView -WebSession $storage -HostGroupName 'test_hosts' `
    -MappingViewName 'test_map' -WhatIf

# Edit the label / description (associations are never touched by Set-DMMappingView)
Set-DMMappingView -WebSession $storage -MappingViewName 'test_map' `
    -Description 'Production database mapping' -WhatIf
Rename-DMMappingView -WebSession $storage -MappingViewName 'test_map' `
    -NewName 'test_map_prod' -WhatIf
```

## Safety Notes

Mapping changes can immediately add or remove host access. Never unmap or
delete mapping views that predate the current validation run.

`Set-DMMappingView` / `Rename-DMMappingView` change only the mapping view's
`NAME`/`DESCRIPTION` labels (REST `PUT /mappingview/{id}`); they never alter the
host-group, LUN-group, or port-group associations that define the access path —
use the `Add-`/`Remove-DM*ToMappingView` commands for that. Both are
`ConfirmImpact = 'High'` because a mapping view is an access-path object, and
never mutate a pre-existing mapping view during validation.

## Integrity Test Coverage

Read-only integrity validates `Get-DMMappingView`. Mutating integrity has
mapping-view and direct-mapping workflows gated by `Mapping.Enabled`, with
dependencies on test-owned LUN, LUN group, host, and host group objects. The
mapping workflow includes a test-owned `Set-DMMappingView` description edit with
a `Set-DMMappingView:ReadBack` verification (the name is left unchanged so
name-based cleanup stays valid).

## Known Gaps

- Port-group lifecycle is not documented in depth here.
- Host-side rescan and multipath validation are outside module tests.

## Related Files

- `POSH-Oceanstor/Public/*MappingView*.ps1`
- `POSH-Oceanstor/Public/*mapLun*.ps1`
- `Tests/Integration/Private/Workflows/Mapping.ps1`
- `Tests/Integration/Private/Workflows/DirectMapping.ps1`
