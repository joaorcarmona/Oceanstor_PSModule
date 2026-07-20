# File Storage Documentation

This folder documents POSH-Oceanstor NAS/file-storage cmdlets: file systems,
NFS and CIFS shares, NFS clients, dTrees, quotas, and file-system snapshots.

## Documentation Map

| Document | Domain | Implemented? |
|---|---|---|
| [file-systems.md](file-systems.md) | File-system lifecycle and performance | Yes |
| [nfs-shares.md](nfs-shares.md) | NFS share lifecycle | Yes |
| [cifs-shares.md](cifs-shares.md) | CIFS share lifecycle | Yes |
| [nfs-clients.md](nfs-clients.md) | NFS client permissions | Yes |
| [dtrees.md](dtrees.md) | dTree lifecycle | Yes |
| [quotas.md](quotas.md) | Directory, user, and user-group quotas | Yes |
| [nas-services.md](nas-services.md) | NAS service configuration | Not implemented here |
| [safety-and-live-validation.md](safety-and-live-validation.md) | Safety rules for live arrays | - |
| [CHANGELOG.md](../../CHANGELOG.md) | Consolidated changelog — completed work, deferred items, safety reference | - |

## Connecting

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru
# Lab arrays with self-signed certificates: add -SkipCertificateCheck
```

## Common Workflow Order

1. Select a storage pool with `Get-DMstoragePool`.
2. Create or inspect a file system with `New-DMFileSystem` and
   `Get-DMFileSystem`.
3. Create a share with `New-DMnfsShare` or `New-DMCifsShare`.
4. Add NFS client permissions with `New-DMnfsClient` when using NFS.
5. Add a dTree and quota only when the workflow requires them.

## Quick Read-Only Inventory

```powershell
Get-DMFileSystem -WebSession $storage
Get-DMShare -WebSession $storage -ShareType NFS
Get-DMShare -WebSession $storage -ShareType CIFS
Get-DMnfsFileClient -WebSession $storage
Get-DMQuota -WebSession $storage -FileSystemName 'fs01'
```

## Compact Inventory Views

Read-only `Select-Object` projections for inventory exports. Field names are the
friendly properties surfaced on the typed objects (multi-word names are quoted);
adjust the columns to the report you need. None of these mutate the array.

```powershell
# File-system inventory
Get-DMFileSystem -WebSession $storage |
    Select-Object Name, Id, 'Health Status', 'Running Status', 'Capacity (GB)', 'Available Capacity'

# Share inventory (shareType is mandatory — run once per type)
Get-DMShare -WebSession $storage -ShareType NFS |
    Select-Object Name, Id, 'Share Path', 'FileSystem ID', 'vStore Name'
Get-DMShare -WebSession $storage -ShareType CIFS |
    Select-Object Name, Id, 'Share Path', 'FileSystem ID', 'Enable ABE', 'vStore Name'

# NFS client-permission inventory
Get-DMnfsFileClient -WebSession $storage |
    Select-Object Name, Id, 'NFS Share Name', 'Access Permission', 'Root Permission Constrain', 'vStore Id'

# Quota inventory (scoped to a parent file system; add -DtreeName for a dTree)
Get-DMQuota -WebSession $storage -FileSystemName 'fs01' |
    Select-Object Id, 'Quota Type', 'Account Name', 'Space Hard Quota', 'Space Used', 'File Hard Quota', 'File Used'
```

Keep the stable `Id` column in any export you plan to feed back into an
automation step — names are for readers, IDs are for machines. On a multi-tenant
array, keep the `vStore Name` column where the object type exposes it.

## Second-Day Operations

The repo implements second-day operations for core NAS objects:
`Set-DMFileSystem`, `Set-DMnfsShare`, `Set-DMnfsClient`, `Set-DMCifsShare`,
`Set-DMdTree`, and `Set-DMQuota`. Broader NAS service configuration, such as
AD/LDAP/CIFS service setup, is not implemented in this cmdlet surface.

## Safety in One Paragraph

NAS mutators can delete file systems, delete shares, change export/client
access, or alter quota behavior. Use `-WhatIf` when learning mutators and run
live mutation tests only against test-owned resources.

## Test Coverage Summary

Read-only integrity validates file-system, share, NFS client, file-system
snapshot, and quota getters where data is available. Mutating integrity has
opt-in test-owned NAS workflows for file systems, file-system rename/resize,
dTrees, NFS, CIFS, file-system snapshots, and quotas.

See [CHANGELOG.md](../../CHANGELOG.md) for completed work and deferred gaps.
