# Block Storage Documentation

This folder documents POSH-Oceanstor cmdlets for SAN/block objects: storage
pools, LUNs, hosts, host groups, initiators, LUN groups, mapping views, and
protection groups.

## Documentation Map

| Document | Domain | Implemented? |
|---|---|---|
| [storage-pools.md](storage-pools.md) | Storage pool inventory and disk lookup | Yes |
| [luns.md](luns.md) | LUN create/read/update/delete and performance wrapper | Yes |
| [hosts-and-host-groups.md](hosts-and-host-groups.md) | Host and host-group lifecycle | Yes |
| [initiators.md](initiators.md) | FC, iSCSI, and NVMe initiators | Yes |
| [lun-groups.md](lun-groups.md) | LUN-group lifecycle and membership | Yes |
| [mapping-views.md](mapping-views.md) | Mapping views and direct mappings | Yes |
| [protection-groups.md](protection-groups.md) | Protection groups for LUN/LUN-group protection workflows | Yes |
| [safety-and-live-validation.md](safety-and-live-validation.md) | Safety rules for live arrays | - |
| [TODO.md](TODO.md) | Confirmed gaps and follow-up work | - |

## Connecting

All examples assume a DeviceManager session:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru
# Lab arrays with self-signed certificates: add -SkipCertificateCheck
```

## Common Workflow Order

1. Select a placement pool with `Get-DMstoragePool`.
2. Create or inspect LUNs with `New-DMLun`, `Get-DMlun`, and `Set-DMLun`.
3. Create or inspect host access with `Get-DMhost`, `New-DMHost`, and initiator cmdlets.
4. Group objects with `New-DMHostGroup` and `New-DMLunGroup` when needed.
5. Present storage through a mapping view or direct mapping cmdlets.
6. Add protection groups only after the protected LUN or LUN group exists.

## Quick Read-Only Inventory

```powershell
Get-DMstoragePool -WebSession $storage
Get-DMlun -WebSession $storage
Get-DMhost -WebSession $storage
Get-DMhostGroup -WebSession $storage
Get-DMlunGroup -WebSession $storage
Get-DMMappingView -WebSession $storage
Get-DMFiberChannelInitiator -WebSession $storage -FreeInitiators
Get-DMIscsiInitiator -WebSession $storage -FreeInitiators
Get-DMNvmeInitiator -WebSession $storage -FreeInitiators
```

## Safety in One Paragraph

Block-storage mutators can create, map, unmap, resize, or delete production
data paths. Use `-WhatIf` when learning any `New-*`, `Set-*`, `Add-*`, or
`Remove-*` command. Never remove a LUN, host mapping, initiator, mapping view,
or protection group unless the object is test-owned or there is an explicit
storage change plan.

## Test Coverage Summary

Read-only integrity covers core getters for LUNs, storage pools, hosts, host
groups, LUN groups, mapping views, initiators, protection groups, and related
by-name/by-ID lookups. Mutating integrity has opt-in workflows for test-owned
LUN, LUN group, host/host group, mapping, direct mapping, initiator, protection
group, and HyperCDP schedule objects.

See [TODO.md](TODO.md) for gaps and [safety-and-live-validation.md](safety-and-live-validation.md)
before running live mutators.
