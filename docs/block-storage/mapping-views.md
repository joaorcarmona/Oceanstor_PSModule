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

## vStore-Scoped Mapping (`-VstoreId`)

On arrays that partition objects into vStores, LUNs, hosts, and mapping objects
live inside a specific vStore rather than the system scope. The direct-mapping
and mapping-view membership cmdlets accept an optional `-VstoreId` that scopes
the operation to that vStore (it is sent as `vstoreId` in the REST body):

- `Add-DMmapLunToHost`, `Remove-DMmapLunFromHost`
- `Add-DMmapLunGroupToHost`, `Remove-DMunmapLunGroupFromHost`
- `Add-DMmapLunGroupToHostGroup`, `Remove-DMunmapLunGroupFromHostGroup`
- `Add-/Remove-DMHostGroupToMappingView`,
  `Add-/Remove-DMLunGroupToMappingView`,
  `Add-/Remove-DMPortGroupToMappingView`, and `New-/Get-DMMappingView`

Guidance:

- Omit `-VstoreId` on a system-scoped (non-multi-tenant) array — the default
  system scope is used.
- When the target LUN/host lives in a vStore, pass that vStore's ID; a mismatch
  between the object's vStore and the mapping scope is a common cause of
  "object not found" or empty-result mapping calls.
- The `-VstoreId` value is an ID, not a name — resolve it from your vStore
  inventory first, and keep it consistent across every step of one workflow.

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Preview a vStore-scoped direct map (mutating cmdlets support -WhatIf)
Add-DMmapLunToHost -WebSession $storage -LunName 'test_lun' -HostName 'test_host' `
    -VstoreId '0' -WhatIf
```

## Legacy Wrapper Migration

The following cmdlets are **deprecated thin wrappers** kept only for backward
compatibility and slated for removal in a future release. Prefer the
server-side-filtered getter parameters instead:

| Deprecated wrapper | Use instead |
|---|---|
| `Get-DMlunByName` | `Get-DMlun -Name` |
| `Get-DMlunByWWN` | `Get-DMlun -WWN` |
| `Get-DMhostbyHostGroup` | `Get-DMhost -HostGroup` / `-HostGroupName` / `-HostGroupId` |

The replacements narrow server-side and compose with other filters; the
wrappers do not add functionality beyond the equivalent parameterized call.

## Relationship Diagram

A mapping view is the join object that ties block access together. Hosts reach
LUNs only when both sides are members of the same mapping view (or through a
direct map). The relationships are:

```
                      Mapping View
        ┌──────────────────┼──────────────────┐
   Host Group          LUN Group           Port Group
        │                  │                    │
      Host              LUN  LUN              Port  Port
        │
   Initiator (FC / iSCSI / NVMe)
```

- A **Host** joins a **Host Group**; its **Initiators** are what the array
  actually authenticates.
- A **LUN** joins a **LUN Group**; the LUN group (not the individual LUN) is
  attached to the mapping view.
- A **Port Group** narrows which front-end ports serve the view (optional).
- Removing a LUN or host almost always means unwinding these memberships first —
  see [mapped-lun-removal-troubleshooting.md](mapped-lun-removal-troubleshooting.md).

## Sample Inventory Views (`Select-Object`)

Read-only projections for inventory exports. Field names follow the raw
DeviceManager properties surfaced on the typed objects; adjust to the columns
your report needs. None of these mutate the array.

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# LUN inventory
Get-DMlun -WebSession $storage |
    Select-Object ID, NAME, WWN, ALLOCTYPE, CAPACITY

# Host / host-group inventory
Get-DMhost -WebSession $storage      | Select-Object ID, NAME, OPERATIONSYSTEM
Get-DMhostGroup -WebSession $storage | Select-Object ID, NAME

# LUN-group inventory
Get-DMlunGroup -WebSession $storage | Select-Object ID, NAME

# Mapping-view inventory with its member-group IDs
Get-DMMappingView -WebSession $storage |
    Select-Object ID, NAME, HOSTGROUPID, LUNGROUPID, PORTGROUPID

# Mapped-LUN relationship discovery: which mapping views expose which groups
Get-DMMappingView -WebSession $storage |
    Select-Object NAME, HOSTGROUPID, LUNGROUPID
```

On a multi-tenant (vStore) array, add the vStore column where the object type
exposes it and keep the `-VstoreId` scope consistent with the objects you are
listing (see [vStore-Scoped Mapping](#vstore-scoped-mapping--vstoreid) above).
Keep the stable `ID` column in any export you plan to feed back into an
automation step — names are for readers, IDs are for machines.

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
