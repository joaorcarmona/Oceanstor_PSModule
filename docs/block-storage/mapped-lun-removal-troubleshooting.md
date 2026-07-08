# Mapped LUN Removal Troubleshooting

## Scope

Diagnosing why a LUN cannot be removed (or should not yet be removed) because it
is still part of an access path. A LUN that is mapped to a host is reachable by
that host's initiators; deleting or unmapping it can immediately sever I/O.
This page is **read-only diagnosis first** — it never prescribes deleting a
pre-existing object.

## Dependency Order

A LUN is usually reachable through a chain of objects. Unwind from the outside
in, and only ever touch objects your own run created:

```
Mapping View
  ├── Host Group ── Host ── Initiator
  ├── LUN Group ── LUN            <-- the LUN you are trying to remove
  └── Port Group ── Port
```

Removal order for a **test-owned** LUN:

1. Remove the LUN from any LUN group (`Remove-DMLunFromLunGroup`) — or the LUN
   group from the mapping view if the whole group is test-owned.
2. Remove any direct LUN-to-host mapping (`Remove-DMmapLunFromHost`).
3. Confirm no mapping view still references the LUN (directly or via its group).
4. Only then delete the LUN itself.

## Safe Read-Only Discovery Before Removal

Establish what the LUN is attached to before changing anything:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# 1. Identify the LUN and its ID (server-side filter)
$lun = Get-DMlun -WebSession $storage -Name 'test_lun'

# 2. Which LUN groups contain it?
Get-DMlunGroup -WebSession $storage

# 3. Which mapping views expose those groups / this LUN?
Get-DMMappingView -WebSession $storage

# 4. Which hosts / host groups are on those mapping views?
Get-DMhost -WebSession $storage
Get-DMhostGroup -WebSession $storage
```

If any of those associations belong to a **pre-existing** object, stop: the LUN
is part of a production access path and must not be removed by automation.

## Common Failure Causes

| Symptom | Likely cause | Read-only check |
|---|---|---|
| Delete rejected: LUN in use / mapped | LUN still in a mapped LUN group or a direct map | `Get-DMMappingView`, `Get-DMlunGroup` |
| "Object not found" on a mapping call | Wrong vStore scope | Confirm `-VstoreId` matches the LUN's vStore ([mapping-views.md](mapping-views.md)) |
| Unmap "succeeds" but host still sees LUN | Host-side rescan not performed | Rescan on the host (outside module scope) |
| LUN group won't delete | Group still referenced by a mapping view | Remove the group from the view first |

## Safety Notes

- Never delete or unmap a LUN, LUN group, mapping view, host, or initiator that
  predates the current validation run.
- Never broad-clean by name pattern after a failure — remove only the exact
  test-owned object by its captured ID.
- Prefer `-WhatIf` to preview every mutating step before running it live.
- Removing a mapping immediately changes host access; sequence the unwind and
  verify at each step rather than deleting bottom-up in one shot.

## Related Files

- [mapping-views.md](mapping-views.md)
- [luns.md](luns.md)
- [lun-groups.md](lun-groups.md)
- `POSH-Oceanstor/Public/*mapLun*.ps1`
- `POSH-Oceanstor/Public/Remove-DMlun.ps1`
