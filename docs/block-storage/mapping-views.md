# Mapping Views

## Scope

Mapping-view inventory and mutation, including host group, LUN group, and port
group membership, plus direct LUN/LUN-group to host/host-group mapping helpers.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMMappingView` | List mapping views or filter by member names | Read | Safe inventory |
| `New-DMMappingView`, `Remove-DMMappingView` | Mapping-view lifecycle | Mutate | Access-path mutation |
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
```

## Safety Notes

Mapping changes can immediately add or remove host access. Never unmap or
delete mapping views that predate the current validation run.

## Integrity Test Coverage

Read-only integrity validates `Get-DMMappingView`. Mutating integrity has
mapping-view and direct-mapping workflows gated by `Mapping.Enabled`, with
dependencies on test-owned LUN, LUN group, host, and host group objects.

## Known Gaps

- Port-group lifecycle is not documented in depth here.
- Host-side rescan and multipath validation are outside module tests.

## Related Files

- `POSH-Oceanstor/Public/*MappingView*.ps1`
- `POSH-Oceanstor/Public/*mapLun*.ps1`
- `Tests/Integration/Private/Workflows/Mapping.ps1`
- `Tests/Integration/Private/Workflows/DirectMapping.ps1`
